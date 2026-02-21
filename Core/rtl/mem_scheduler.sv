module mem_scheduler (
    //lsu and pc interface
    input logic clk, reset,
    input logic [3 : 0]  request,
    input logic [15 : 0] active_mask,
    input logic [15 : 0] addr_in [0 : 15],
    input logic [15 : 0]   sw_out [0 : 15],
    output logic [15 : 0]  lw_out [0 : 15],
    output logic stall,
    output logic mem_write,

    //memory interface
    input logic [15 : 0] lw_in,
    output logic[15 : 0] addr_out,
    output logic[15 : 0] sw_out_mem
); 


typedef enum logic [2 : 0] {
    IDLE    = 3'b000,
    REQ     = 3'b001,
    WAIT    = 3'b010,
    CAPTURE = 3'b011,
    DONE    = 3'b100
} state_t;

state_t state_curr;
integer curr_lane;

logic request_reg;

assign stall = (state_curr == REQ)     ||
               (state_curr == WAIT)    ||
               (state_curr == CAPTURE) ||
               (state_curr == IDLE && (request == 4'b0110 || request == 4'b0111));

always_ff @(posedge clk) begin 
    if (reset) begin
        state_curr  <= IDLE;
        
        sw_out_mem  <= 16'h0000;
        addr_out    <= 16'h0000;
        curr_lane   <= 0;
        mem_write   <= 0;
        request_reg <= 0;
        for(integer i = 0; i < 16; i++) begin
            lw_out[i]      <= 16'b0;
        end
    end else begin
        case (state_curr)
            IDLE: begin
                if(request == 4'b0110 || request == 4'b0111) begin 
                    
                    curr_lane  <= 0; 
                    request_reg <= (request == 4'b0110);
                    state_curr <= REQ; 
                end
                addr_out   <= 16'h0000;
                sw_out_mem <= 16'h0000;
                mem_write  <= 0;
            end

            REQ: begin
                mem_write   <= 0;
                if(request_reg) begin //lw
                    if(curr_lane < 16) begin
                        if(active_mask[curr_lane]) begin
                            addr_out    <= addr_in[curr_lane];
                            state_curr  <= WAIT;
                        end else begin
                            curr_lane   <= curr_lane + 1; 
                            state_curr  <= REQ;
                        end
                    end
                    else if(curr_lane >= 16) begin
                        state_curr <= DONE;
                    end 
                end
                else begin //sw
                    if(curr_lane < 16) begin
                        if(active_mask[curr_lane]) begin
                            mem_write   <= 1;
                            addr_out    <= addr_in[curr_lane];
                            sw_out_mem  <= sw_out[curr_lane];
                            state_curr  <= WAIT;
                        end else begin
                            curr_lane   <= curr_lane + 1; 
                            state_curr  <= REQ;
                        end
                    end
                    else if(curr_lane >= 16) begin
                        state_curr <= DONE;
                    end                   
                end
            end

            WAIT: begin
                state_curr <= CAPTURE;
            end

            CAPTURE: begin //lw    
            if(request_reg) begin
                    lw_out[curr_lane] <= lw_in;  
                end
            curr_lane   <= curr_lane + 1;
            state_curr  <= REQ;    
            end


            DONE: begin
                
                curr_lane  <= 0;
                state_curr <= IDLE;
            end
            default: state_curr <= IDLE;
        endcase
    end
end  

endmodule