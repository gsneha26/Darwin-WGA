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
module BSW_PE #(
    parameter WIDTH = 10,
    parameter REF_LEN_WIDTH = 10,
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
    input set_param,
    
    input  [WIDTH-1:0] V_in,        // Score from previous PE
    input  [WIDTH-1:0] M_in,        // match score from previous PE
    input  [WIDTH-1:0] F_in,        // Gap penalty of previous PE
    input  [2:0] T_in,              // Reference seq shift in
    input  init_in,                 // Computation active shift in
    input  [WIDTH-1:0] init_V,      // V initialization value
    input  [WIDTH-1:0] init_E,      // E initialization value
    input  [WIDTH-1:0] init_M,      // M initialization value
    
    input [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_in,
    input [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_in,
    input [QUERY_LEN_WIDTH-1:0] max_query_mod_in,
    input [QUERY_LEN_WIDTH-1:0] max_stripe_num_in,
    input [LOG_NUM_PE-1:0] max_query_pos_in,
    
    input last_query_sent,
    input compute_max_in,
    
    input [REF_LEN_WIDTH-1:0] start_pos,
    input [REF_LEN_WIDTH-1:0] ref_length,
    input [BT_BRAM_ADDR_WIDTH-1:0] current_position,

    output reg [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_out,
    output reg [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_out,
    output reg [LOG_NUM_PE-1:0] max_query_pos_out,
    output reg [QUERY_LEN_WIDTH-1:0] max_query_mod_out,
    output reg [QUERY_LEN_WIDTH-1:0] max_stripe_num_out,

    output reg compute_max_out,
    output wire [WIDTH-1:0] V_out,       // Score of this PE
    output wire [WIDTH-1:0] E_out,       // Left gap penalty of this cell
    output wire [WIDTH-1:0] F_out,       // Up Gap penalty of this cell
    output wire [WIDTH-1:0] M_out,       // Match score of this cell
    output wire [2:0] T_out,             // Reference seq shift out
    output wire init_out,                // Computation active shift out
    output reg [REF_LEN_WIDTH-1:0] curr_ref_mod
    );
    
    localparam ZERO=0, MATCH=3, VER=1, HOR=2;

    reg [2:0] T;
    reg signed [WIDTH-1:0] V_diag;
    reg signed [WIDTH-1:0] V;
    reg signed [WIDTH-1:0] M;
    reg signed [WIDTH-1:0] E;
    reg signed [WIDTH-1:0] F;
    reg signed [WIDTH-1:0] max_V;

    reg init;

    reg [BT_BRAM_ADDR_WIDTH-1:0] curr_ref_pos;
    reg [QUERY_LEN_WIDTH-1:0] stripe_num;
    reg [QUERY_LEN_WIDTH-1:0] curr_query_mod;

    reg signed [WIDTH-1:0] sub_A;
    reg signed [WIDTH-1:0] sub_C;
    reg signed [WIDTH-1:0] sub_G;
    reg signed [WIDTH-1:0] sub_T;
    reg signed [WIDTH-1:0] sub_N;
    reg signed [WIDTH-1:0] gap_open;
    reg signed [WIDTH-1:0] gap_extend;
    
    reg signed [WIDTH-1:0] V_gap_open;
    reg signed [WIDTH-1:0] E_gap_extend;
    reg signed [WIDTH-1:0] upV_gap_open;
    reg signed [WIDTH-1:0] upF_gap_extend;
    reg signed [WIDTH-1:0] match_score;
    reg signed [WIDTH-1:0] new_E;
    reg signed [WIDTH-1:0] new_M;
    reg signed [WIDTH-1:0] new_F;
    reg signed [WIDTH-1:0] new_V;
    reg signed [WIDTH-1:0] match_reward;

    reg stop_last_query_sent;

    assign V_out = V;
    assign M_out = M;
    assign E_out = E;
    assign F_out = F;
    assign T_out = T;
    assign init_out = init;
    
    always @(*) begin
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
    always @(posedge clk) begin

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
        end
        else begin
            new_E = E_gap_extend;
        end
        
        //I(i,j)
        if ($signed(upV_gap_open) >= $signed(upF_gap_extend)) begin
            new_F = upV_gap_open;
        end
        else begin
            new_F = upF_gap_extend;
        end
   
        if (0 >= $signed(new_E) && 0 >= $signed(new_F) && 0 >= $signed(match_score)) begin
            new_V = 0;
        end
        else if ($signed(new_F) >= $signed(new_E) && $signed(new_F) >= $signed(match_score)) begin
            new_V = new_F;
        end
        else if ($signed(new_E) >= $signed(match_score)) begin
            new_V = new_E;
        end
        else begin
            new_V = match_score;
        end
    end

    always @(posedge clk) begin

        if (rst) begin
            max_ref_pos_out <= 0;
            max_ref_mod_out <= 0;
            max_query_mod_out <= 0;
            max_V <= 0;
            max_stripe_num_out <= 0;
        end

        //current PE computes the last cell, init - registered value of init_in,
        else if ((init == 1'b1) && ((stop_last_query_sent==0 && V >= max_V))) begin
            max_ref_pos_out <= curr_ref_pos - 1;
            max_ref_mod_out <= curr_ref_mod - 1;
            max_query_mod_out <= curr_query_mod - 1;
            max_V <= V;
            max_stripe_num_out <= stripe_num;
        end

        //compute_max_in - start sending the max in systolic fashion, each PE
        //compares the max_V to its own max and sends the final value outside
        else if (compute_max_in) begin
            if (max_V < V_in) begin
                max_ref_pos_out <= max_ref_pos_in;
                max_ref_mod_out <= max_ref_mod_in;
                max_query_mod_out <= max_query_mod_in;
                max_stripe_num_out <= max_stripe_num_in;
            end
        end
    end

    always @(posedge clk) begin
        //reset/initialize variable
        if (rst) begin
            T <= 0;
            V_diag <= 0;
            M <= 0;
            V <= 0;
            E <= (2'b11 << (WIDTH-2));
            F <= 0;
            init <= 0;
            curr_ref_pos <= 0;
            curr_ref_mod <= 0;
            curr_query_mod <= 0;
            max_query_pos_out <= PE_ID;
            compute_max_out <= 0;
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
            init <= 0; 
            curr_ref_pos <= current_position;
            curr_ref_mod <= start_pos;
            curr_query_mod <= curr_query_mod + 1;
            V <= init_V;
            E <= init_E;
            M <= 0;
            stop_last_query_sent <= last_query_sent;
            stripe_num <= stripe_num +1;
            V_diag <= 0;

        //actual calculation
        end 
        else begin
            init <= init_in;
            T <= T_in;
            compute_max_out <= compute_max_in;
           
            //init_in refers to the valid signal that the previous PE has
            //completed the computation and the input to the current PE can now
            //be used
            if (init_in) begin
                E <= new_E;
                F <= new_F;
                M <= ($signed(match_score) >= 0) ? match_score :0;
                V_diag <= V_in;
                V <= new_V;
                curr_ref_mod <= curr_ref_mod + 1;
            end 
            else if (compute_max_in) begin
                //if the current PE holds a value of V greater than the V sent by the
                //previous PE
                if (max_V >= V_in) begin
                    V <= max_V;
                    max_query_pos_out <= PE_ID;
                end

                //bypass if the current PE max value is less than the previous
                //PE max_V
                else begin
                    max_query_pos_out <= max_query_pos_in;
                    V <= V_in; 
                end
            end 
        end
    end
endmodule

