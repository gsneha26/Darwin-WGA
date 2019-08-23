/*
MIT License

Copyright (c) 2019 Sneha D. Goenka, Yatish Turakhia, Gill Bejerano and William J. Dally

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/// V <-> H
// F <-> I
// E <-> D
//
module GACTX_NWPE #(
    parameter WIDTH = 10,
    parameter REF_WIDTH = 10,
    parameter BT_BRAM_ADDR_WIDTH = 10,
    parameter QUERY_LEN_WIDTH = 10,
    parameter LOG_NUM_PE = 2,
    parameter PE_ID = 0
)(
    input  clk,                     // System clock
    input  rst,                     // System reset
    
    // Scoring parameters (basically separate indices of the parameter
    // calculated in Nt2Param
    input [WIDTH-1:0] sub_A_in,
    input [WIDTH-1:0] sub_C_in,
    input [WIDTH-1:0] sub_G_in,
    input [WIDTH-1:0] sub_T_in,
    input [WIDTH-1:0] sub_N_in,
    input [WIDTH-1:0] gap_open_in,
    input [WIDTH-1:0] gap_extend_in,
    input [WIDTH-1:0] y_in,
    input set_param,
    
    input  [WIDTH-1:0] V_in,        // Score from previous PE
    input  [WIDTH-1:0] M_in,        // match score from previous PE
    input  [WIDTH-1:0] F_in,        // Gap penalty of previous PE
    input  [WIDTH-1:0] E_in,        // Gap penalty of previous PE
    input  [2:0] T_in,              // Reference seq shift in
    input  init_in,                 // Computation active shift in
    input  [WIDTH-1:0] init_V,      // V initialization value
    input  [WIDTH-1:0] init_E,      // E initialization value
    input  [WIDTH-1:0] init_M,      // M initialization value
    
    input start_final,
    input [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_in,
    input [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_in,
    input [QUERY_LEN_WIDTH-1:0] max_query_mod_in,
    input [QUERY_LEN_WIDTH-1:0] max_stripe_num_in,
    input [LOG_NUM_PE-1:0] max_query_pos_in,
    input [1:0] max_pe_state_in,

    
    input last_query_sent,
    input compute_max_in,
    input compute_global_max_in,
    input last,
    input last_in,
    input [WIDTH-1:0] global_max_in,
    input [WIDTH-1:0] max_with_y,
    
    input [REF_WIDTH-1:0] start_pos,
    input [REF_WIDTH-1:0] stop_pos,
    input [REF_WIDTH-1:0] ref_length,
    input [QUERY_LEN_WIDTH-1:0] query_length,
    input start_increment,
    input start_transmit_in,
    input [BT_BRAM_ADDR_WIDTH-1:0] current_position,

    output wire [WIDTH-1:0] global_max_out,
    output reg [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_out,
    output reg [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_out,
    output reg [LOG_NUM_PE-1:0] max_query_pos_out,
    output reg [QUERY_LEN_WIDTH-1:0] max_query_mod_out,
    output reg [1:0] max_pe_state_out,
    output reg [QUERY_LEN_WIDTH-1:0] max_stripe_num_out,

    output reg start_transmit_out,
    output reg compute_max_out,
    output reg compute_global_max_out,
    output reg last_out,
    output wire [WIDTH-1:0] V_out,       // Score of this PE
    output wire [WIDTH-1:0] E_out,       // Left gap penalty of this cell
    output wire [WIDTH-1:0] F_out,       // Up Gap penalty of this cell
    output wire [WIDTH-1:0] M_out,       // Match score of this cell
    output wire [2:0] T_out,             // Reference seq shift out
    output wire init_out,                // Computation active shift out
    output reg dir_valid,
    output wire [BT_BRAM_ADDR_WIDTH-1:0] dir_addr, 
    output reg signed [3:0] dir, 
    output wire max_with_y_out,
    output reg [REF_WIDTH-1:0] curr_ref_mod
    );
    
    localparam ZERO=0, MATCH=3, VER=1, HOR=2;

    reg [2:0] T;
    reg signed [WIDTH-1:0] V_diag;
    reg signed [WIDTH-1:0] F_diag;
    reg signed [WIDTH-1:0] E_diag;
    reg signed [WIDTH-1:0] V;
    reg signed [WIDTH-1:0] M;
    reg signed [WIDTH-1:0] E;
    reg signed [WIDTH-1:0] F;
    reg signed [WIDTH-1:0] max_V;

    reg store_S;
    reg init;
    reg reg_last;

    reg [BT_BRAM_ADDR_WIDTH-1:0] curr_ref_pos;
    reg [QUERY_LEN_WIDTH-1:0] stripe_num;
    reg [QUERY_LEN_WIDTH-1:0] curr_query_mod;
    reg [REF_WIDTH-1:0] curr_start_pos;
    reg [REF_WIDTH-1:0] prev_start_pos;

    reg signed [WIDTH-1:0] sub_A;
    reg signed [WIDTH-1:0] sub_C;
    reg signed [WIDTH-1:0] sub_G;
    reg signed [WIDTH-1:0] sub_T;
    reg signed [WIDTH-1:0] sub_N;
    reg signed [WIDTH-1:0] gap_open;
    reg signed [WIDTH-1:0] gap_extend;
    reg signed [WIDTH-1:0] y;
    
    reg signed [WIDTH-1:0] V_gap_open;
    reg signed [WIDTH-1:0] E_gap_extend;
    reg signed [WIDTH-1:0] upV_gap_open;
    reg signed [WIDTH-1:0] upF_gap_extend;
    reg signed [WIDTH-1:0] match_score;
    reg signed [WIDTH-1:0] match_scoreF;
    reg signed [WIDTH-1:0] match_scoreE;
    reg signed [WIDTH-1:0] match_scoreV;
    reg signed [WIDTH-1:0] new_E;
    reg signed [WIDTH-1:0] new_M;
    reg signed [WIDTH-1:0] new_F;
    reg signed [WIDTH-1:0] new_V;
    reg [3:0] new_dir;
    reg signed [WIDTH-1:0] global_max_out_reg;
    reg signed [WIDTH-1:0] match_reward;

    reg [1:0] pe_state;
    reg [1:0] last_pe_state;
    reg compute_global_max_in_reg;
    reg stop_last_query_sent;

    assign global_max_out = global_max_out_reg;
    assign V_out = V;
    assign M_out = M;
    assign E_out = E;
    assign F_out = F;
    assign T_out = T;
    assign init_out = init;
    assign store_S_out = store_S;
    assign dir_addr = curr_ref_pos-1;
    
    always @(*) begin
        y <= y_in;
        case ({T_in})//reference sequence base pair for reward calculation (W(r_i,q_j)) to calc match_score
            3'b000 : match_reward = sub_N;
            3'b001 : match_reward = sub_A;
            3'b010 : match_reward = sub_C;
            3'b011 : match_reward = sub_G;
            3'b100 : match_reward = sub_T;
            default : match_reward = 0;
        endcase
    end
    
    //Score calculation
    always @(*) begin


        //for D matrix
        V_gap_open = M + gap_open;
        E_gap_extend = E + gap_extend;
        
        //for I matrix
        upV_gap_open = M_in + gap_open;
        upF_gap_extend = F_in + gap_extend;
        
        //H(i-1,j-1)+W(r_i,q_j)
        match_score = V_diag + match_reward;          
        
        //D(i,j)
        if ($signed(V_gap_open) >= $signed(E_gap_extend)) begin
            new_E = V_gap_open;
            new_dir[3] = 1;
        end
        else begin
            new_E = E_gap_extend;
            new_dir[3] = 0;
        end
        
        //I(i,j)
        if ($signed(upV_gap_open) >= $signed(upF_gap_extend)) begin
            new_F = upV_gap_open;
            new_dir[2] = 1;
        end
        else begin
            new_F = upF_gap_extend;
            new_dir[2] = 0;
        end
            
        //calculating max and final state
        //no 0 comparison case in NW
        if ($signed(match_score) >= $signed(new_E) && $signed(match_score) >= $signed(new_F)) begin
            new_V = match_score;
            pe_state = MATCH;
            new_dir[1:0] = 3;
        end
        else if ($signed(new_F) >= $signed(new_E)) begin
            new_V = new_F;
            pe_state = VER;
            new_dir[1:0] = 1;
        end
        else begin
            new_V = new_E;
            pe_state = HOR;
            new_dir[1:0] = 2;
        end
    end

    always @(posedge clk) begin

        last_pe_state <= pe_state;
        if (rst) begin
            max_ref_pos_out <= 0;
            max_ref_mod_out <= 0;
            max_query_mod_out <= 0;
            max_pe_state_out <= 0;
            max_V <= 0;
            max_stripe_num_out <= 0;
        end

        //reg_last - registered value of the signal that says whether or not the
        //current PE computes the last cell, init - registered value of init_in,
        else if ((init == 1'b1) && ((reg_last == 1'b1) || (stop_last_query_sent==0 &&  $signed(V) >= $signed(max_V)))) begin
            max_ref_pos_out <= curr_ref_pos - 1;
            max_ref_mod_out <= curr_ref_mod - 1;
            max_query_mod_out <= curr_query_mod - 1;
            max_pe_state_out <= last_pe_state;
            max_V <= V;
            max_stripe_num_out <= stripe_num;
        end

        //compute_max_in - start sending the max in systolic fashion, each PE
        //compares the max_V to its own max and sends the final value outside
        else if (compute_max_in) begin
            //last_in - signal from the previous PE telling whether or not it
            //calculates the last cell of the matrix, reg_last - registered
            //value of the last signal of the current PE
            if ((($signed(max_V) < $signed(V_in)) || (last_in == 1'b1)) && (reg_last == 1'b0)) begin
                max_ref_pos_out <= max_ref_pos_in;
                max_ref_mod_out <= max_ref_mod_in;
                max_query_mod_out <= max_query_mod_in;
                max_pe_state_out <= max_pe_state_in;
                max_stripe_num_out <= max_stripe_num_in;
            end
        end
    end

    always @(posedge clk) begin
        //reset/initialize variable
        if (rst) begin
            T <= 0;
            V_diag <= 0;
            F_diag <= 0;
            E_diag <= 0;
            M <= 0;
            V <= 0;
            E <= (2'b11 << (WIDTH-2));
            F <= 0;
            store_S <= 0;
            init <= 0;
            dir <= 0;
            dir_valid <= 0;
            curr_ref_pos <= 0;
            curr_ref_mod <= 0;
            prev_start_pos <= 0;
            curr_start_pos <= 0;
            curr_query_mod <= 0;
            max_query_pos_out <= PE_ID;
            compute_max_out <= 0;
            compute_global_max_out <= 0;
            reg_last <= 0;
            stripe_num <= -1;
            stop_last_query_sent <= 0;
        //set the parameters
        end 
        else if (set_param) begin
            sub_A <= sub_A_in;
            sub_C <= sub_C_in;
            sub_G <= sub_G_in;
            sub_T <= sub_T_in;
            sub_N <= sub_N_in;
            gap_open <= gap_open_in;
            gap_extend <= gap_extend_in;
            reg_last <= last;
            init <= 0; 
            dir_valid <= 0;
            curr_start_pos <= start_pos;
            prev_start_pos <= curr_start_pos;
            curr_ref_pos <= current_position;
            curr_ref_mod <= start_pos;
            curr_query_mod <= curr_query_mod + 1;
            V <= init_V;
            E <= init_E;
            M <= init_M;
            stop_last_query_sent <= last_query_sent;
            stripe_num <= stripe_num +1;
            
            F_diag <= (2'b11) << (WIDTH-2);
            E_diag <= (2'b11) << (WIDTH-2);
            //V_diag for the first element of each row
            if((curr_query_mod==0 && PE_ID==0)) begin
                V_diag <= init_V - gap_open_in;
            end
            else if(start_pos == 0) begin
                V_diag <= init_V - gap_extend_in;
            end
            else begin
                V_diag <= (2'b11) << (WIDTH-2);
            end

        //actual calculation
        end 
        else begin

            init <= init_in;
            T <= T_in;
            compute_max_out <= compute_max_in;
            compute_global_max_out <= compute_global_max_in;
            last_out <= (reg_last | last_in);
            compute_global_max_in_reg <= compute_global_max_in;
            start_transmit_out <= start_transmit_in;
           
            //init_in refers to the valid signal that the previous PE has
            //completed the computation and the input to the current PE can now
            //be used
            if (init_in) begin
                E <= new_E;
                F <= new_F;
                M <= match_score;
                V_diag <= V_in;
                F_diag <= F_in;
                E_diag <= E_in;
                V <= new_V;
                dir <= new_dir;
                dir_valid <= 1;
                curr_ref_mod <= curr_ref_mod + 1;
                curr_ref_pos <= curr_ref_pos +1;
            end 
            else if (compute_max_in) begin
                //if the current PE holds a value of V greater than the V sent by the
                //previous PE
                if (((($signed(max_V) >= $signed(V_in)) || (reg_last == 1'b1))) && (last_in == 1'b0)) begin
                    V <= max_V;
                    max_query_pos_out <= PE_ID;
                end

                //bypass if the current PE max value is less than the previous
                //PE max_V
                else begin
                    max_query_pos_out <= max_query_pos_in;
                    V <= V_in; 
                end
                dir_valid <= 0;
            end 
            else begin
                dir_valid <= 0;
            end

        end
    end

    generate
        assign max_with_y_out = ($signed(V) >= $signed(max_with_y)) ? 1 : 0;
    endgenerate

    always@(posedge clk) begin
        if(rst) begin
            global_max_out_reg <= 0;
        end
        else if (!set_param) begin
            if(compute_global_max_in ==1) begin
                if($signed(global_max_in) >= $signed(V) && $signed(global_max_in) > $signed(global_max_out)) begin
                    global_max_out_reg <= global_max_in;
                end
                else begin
                    if($signed(global_max_out) < $signed(V) && $signed(global_max_in) < $signed(V)) begin
                        global_max_out_reg <= V;
                    end
                end
            end
        end
    end

endmodule

