module mem_scheduler (
    //data memory and pc interface
    input logic clk, reset,
    input logic [3 : 0]  request,
    input logic [15 : 0] active_mask,
    input logic [15 : 0] addr_in [0 : 15],
    input logic [15 : 0]   sw_out [0 : 15],
    output logic [15 : 0]  lw_out [0 : 15],
    output logic stall,
    output logic mem_write,

    //warp scheduler interface 
    input logic mem_req, // from top
    input logic[1 : 0] warp_id_from_ws,//warp id from warp-scheduler
    output logic mem_done, // to warp scheduler
    output logic[1 : 0] warp_id_to_ws, //warp_id returned to scheduler
    // output logic[1 : 0] current_warp_id,
    input logic[3 : 0] lw_destination,
    output logic[3 : 0] lw_destination_out,

    //data memory interface
    input logic [15 : 0] lw_in,
    output logic[15 : 0] addr_out,
    output logic[15 : 0] sw_out_mem,

    //top interface
    output logic[1 : 0] lw_warp_id,
    output logic        lw_ready
); 
reg[15 : 0] ADDR       [0 : 3][0 : 15];
reg[15 : 0] SW_DATA       [0 : 3][0 : 15];
reg[1 : 0] WARP_NUMBER [0 : 3];
reg        REQ_DONE    [0 : 3];
reg        OCCUPIED    [0 : 3];
reg        REQ_TYPE    [0 : 3];
reg[3 : 0] DESTINATION [0 : 3];


typedef enum logic [2 : 0] {
    IDLE    = 3'b000,
    WARP    = 3'b001,
    REQ_CHECK = 3'b010,
    REQ     = 3'b011,
    WAIT    = 3'b100,
    CAPTURE = 3'b101,
    DONE    = 3'b110
} state_t;

state_t state_curr;
integer curr_lane;

logic request_reg;
logic[1 : 0] current_warp_in_ms;
logic[1 : 0] queue_pointer;

assign stall = (state_curr == REQ)     ||
               (state_curr == WAIT)    ||
               (state_curr == CAPTURE) ||
               (state_curr == IDLE && mem_req);

always_ff @(posedge clk) begin 
    if (reset) begin
        state_curr  <= IDLE;
        
        sw_out_mem    <= 16'h0000;
        addr_out      <= 16'h0000;
        curr_lane     <= 0;
        mem_write     <= 0;
        request_reg   <= 0;
        lw_warp_id    <= 0;
        lw_ready      <= 0;
        mem_done      <= 0;
        warp_id_to_ws <= 2'b00;
        current_warp_in_ms <= 2'b00;
        queue_pointer      <= 2'b00;
        lw_destination_out <= 4'h0;
        for(integer i = 0; i < 16; i++) begin
            lw_out[i]      <= 16'b0;
            if(i < 4) begin
                WARP_NUMBER[i] <= 2'b00;
                REQ_DONE[i]    <= 1;
                OCCUPIED[i]    <= 0;
                REQ_TYPE[i]    <= 0;
                DESTINATION[i] <= 4'h0;
            end
            for(integer j = 0; j < 4; j++) begin
                ADDR[j][i]    <= 16'h0000;
                SW_DATA[j][i] <= 16'h0000;
            end
        end
    end else begin
        case (state_curr)
            IDLE: begin
                if(mem_req) begin //look for lw/sw and store in table
                logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end 
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end
                        end
                    end 
                    curr_lane   <= 0; 
                    state_curr  <= WARP; 
                end
                else if(!(REQ_DONE[0] && REQ_DONE[1] && REQ_DONE[2] && REQ_DONE[3])) begin //find next warp if any left 
                    state_curr <= WARP; 
                    curr_lane  <= 0;
                end
                addr_out   <= 16'h0000;
                sw_out_mem <= 16'h0000;
                mem_write  <= 0;
                mem_done   <= 0;
                lw_ready   <= 0;
            end

            WARP: begin
                if(mem_req) begin //look for lw/sw and store in table
                    logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end                            
                        end
                    end                    
                end

                begin
                logic found_warp = 0;  //next warp tp execute
                for (integer i = 0; i < 4; i++) begin
                    if(REQ_DONE[i] == 0 && found_warp == 0) begin
                        current_warp_in_ms <= WARP_NUMBER[i];
                        queue_pointer      <= i;
                        found_warp          = 1;
                        request_reg        <= REQ_TYPE[i];
                    end
                end
                state_curr  <= REQ_CHECK;
                request_reg <= REQ_TYPE[queue_pointer];
            end
            end

            REQ_CHECK: begin
                if(mem_req) begin //look for lw/sw and store in table
                    logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end                            
                        end
                    end                    
                end
                request_reg <= REQ_TYPE[queue_pointer];
                state_curr  <= REQ;
            end

            REQ: begin
                if(mem_req) begin //look for lw/sw and store in table
                    logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end
                        end
                    end                    
                end


                mem_write   <= 0;
                if(request_reg) begin //lw
                    if(curr_lane < 16) begin
                        if(active_mask[curr_lane]) begin
                            addr_out    <= ADDR[current_warp_in_ms][curr_lane];
                            state_curr  <= WAIT;
                        end else begin
                            curr_lane   <= curr_lane + 1; 
                            state_curr  <= REQ;
                        end
                    end
                    else if(curr_lane >= 16) begin
                        state_curr <= DONE;
                        REQ_DONE[queue_pointer] <= 1;
                        lw_destination_out      <= DESTINATION[queue_pointer];
                        lw_ready   <= 1;
                        lw_warp_id <= current_warp_in_ms;
                    end 
                end

                else begin //sw
                    if(curr_lane < 16) begin
                        if(active_mask[curr_lane]) begin
                            mem_write   <= 1;
                            addr_out    <= ADDR[current_warp_in_ms][curr_lane];
                            sw_out_mem  <= SW_DATA[current_warp_in_ms][curr_lane];
                            state_curr  <= WAIT;
                        end else begin
                            curr_lane   <= curr_lane + 1; 
                            state_curr  <= REQ;
                        end
                    end
                    else if(curr_lane >= 16) begin
                        state_curr <= DONE;

                        REQ_DONE[queue_pointer] <= 1;
                    end                   
                end
            end

            WAIT: begin
                if(mem_req) begin //look for lw/sw and store in table
                    logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found          = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end
                        end
                    end                    
                end

                state_curr <= CAPTURE;
            end

            CAPTURE: begin //lw  
                if(mem_req) begin //look for lw/sw and store in table
                logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end
                        end
                    end                
                end


            if(request_reg) begin
                    lw_out[curr_lane] <= lw_in;  
                end
            curr_lane   <= curr_lane + 1;
            state_curr  <= REQ;    
            end


            DONE: begin
                if(mem_req) begin //look for lw/sw and store in table
                logic found = 0;
                    for (integer i = 0; i < 4; i++) begin
                        if(OCCUPIED[i] == 0 && found == 0) begin
                            WARP_NUMBER[i] <= warp_id_from_ws;
                            OCCUPIED[i]    <= 1;
                            REQ_DONE[i]    <= 0;
                            REQ_TYPE[i]    <= (request == 4'b0110);
                            if(request == 4'b0110) begin
                                DESTINATION[i] <= lw_destination;
                            end
                            found           = 1;
                            for(integer j = 0; j < 16; j++) begin
                                ADDR[warp_id_from_ws][j]    <= addr_in[j];
                                SW_DATA[warp_id_from_ws][j] <= sw_out[j];
                            end
                        end
                    end                    
                end

                mem_done   <= 1;
                curr_lane  <= 0;
                state_curr <= IDLE;
                OCCUPIED[queue_pointer] <= 0;
                warp_id_to_ws                   <= current_warp_in_ms;
            end
            default: state_curr <= IDLE;
        endcase
    end
end  

// assign current_warp_id = current_warp_in_ms;
endmodule
