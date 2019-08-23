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

/* ref_length should be greater than NUM_PE
* and NUM_PE should be power of 2.
*/
module GACTX_ArrayTop #(
    parameter NUM_PE = 32,
    parameter LOG_NUM_PE = 5,
    parameter REF_LEN_WIDTH = 10,
    parameter QUERY_LEN_WIDTH = 10,
    parameter PE_WIDTH = 8,
    parameter PARAM_ADDR_WIDTH = 10
)(
    input  clk,         
    input  rst,        
    input start,
    input [13*PE_WIDTH-1:0] in_param,

    input reverse_ref_in,
    input reverse_query_in,

    input complement_ref_in,
    input complement_query_in,

    input [REF_LEN_WIDTH-1:0] ref_length,
    input [QUERY_LEN_WIDTH-1:0] query_length,

    output reg [REF_LEN_WIDTH-1:0] ref_bram_rd_addr, 
    input [7:0] ref_bram_data_in,
    output reg [PARAM_ADDR_WIDTH-1:0] query_bram_rd_addr,
    input [7:0] query_bram_data_in,

    input [PE_WIDTH-1:0] y_in, 
    input start_last,

    output reg [PE_WIDTH-1:0] max_score,
    output reg [REF_LEN_WIDTH-1:0] H_offset,
    input [REF_LEN_WIDTH-1:0] max_H_offset,
    output reg [QUERY_LEN_WIDTH-1:0] V_offset,
    input [QUERY_LEN_WIDTH-1:0] max_V_offset,

    output reg [REF_LEN_WIDTH-1:0] ref_max_score_pos,
    output reg [QUERY_LEN_WIDTH-1:0] query_max_score_pos,

    output reg [(REF_LEN_WIDTH + (QUERY_LEN_WIDTH - LOG_NUM_PE))+LOG_NUM_PE-1:0] num_tb_steps,

    output wire [1:0] dir,
    output wire dir_valid,

    output done);

    localparam PARAM_WIDTH = 4 * PE_WIDTH;
    
    localparam BT_BRAM_ADDR_WIDTH = 22 - LOG_NUM_PE;
    localparam V_FIFO_DEPTH_WIDTH = REF_LEN_WIDTH;
    localparam M_FIFO_DEPTH_WIDTH = REF_LEN_WIDTH;
    localparam F_FIFO_DEPTH_WIDTH = REF_LEN_WIDTH;

    reg first_query_block;

    reg global_max_fifo_rd_en;

    reg [NUM_PE-1:0] set_param;
    reg [NUM_PE-1:0] last;
    wire [PARAM_WIDTH-1:0] param;
    wire [PARAM_WIDTH-1:0] param_out;

    reg [REF_LEN_WIDTH-1:0] curr_ref_len;
    reg [QUERY_LEN_WIDTH-1:0] curr_query_len;
    
    reg reverse_query, reverse_ref;
    reg complement_query, complement_ref;

    reg rst_pe[NUM_PE-1:0];
    reg [3:0] state;

    wire [3:0] ref_nt; 
    wire [3:0] query_nt; 

    wire [4*NUM_PE-1:0] select_dir_data_in;
  
    wire [PE_WIDTH-1:0] sub_A_in;
    wire [PE_WIDTH-1:0] sub_C_in;
    wire [PE_WIDTH-1:0] sub_G_in;
    wire [PE_WIDTH-1:0] sub_T_in;
    reg [PE_WIDTH-1:0] sub_N_in;

    wire [PE_WIDTH-1:0] y; 
    wire [PE_WIDTH-1:0] F_in[0:NUM_PE-1];
    wire [2:0] T_in[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] V_in[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] M_in[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] E_in[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] F_out[0:NUM_PE-1];
    wire [2:0] T_out[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] V_out[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] M_out[0:NUM_PE-1];
    wire [PE_WIDTH-1:0] E_out[0:NUM_PE-1];

    reg [PE_WIDTH-1:0] reg_init_V;
    wire [PE_WIDTH-1:0] init_V;
    wire [PE_WIDTH-1:0] init_M;
    wire [PE_WIDTH-1:0] init_E;

    wire [3:0] pe_dir [0:NUM_PE-1];
    wire [BT_BRAM_ADDR_WIDTH-1:0] pe_dir_addr [0:NUM_PE-1];
    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_current_addr [0:NUM_PE-1];
    wire pe_dir_valid [0:NUM_PE-1];
    wire pe_dir_valid_y_drop [0:NUM_PE-1];

    wire init_in [0:NUM_PE-1];
    wire init_out [0:NUM_PE-1];
    wire start_transmit_out [0:NUM_PE-1];
    wire start_transmit_in [0:NUM_PE-1];

    wire [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_in [0:NUM_PE-1];
    wire [BT_BRAM_ADDR_WIDTH-1:0] max_ref_pos_out [0:NUM_PE-1];
    wire [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_in [0:NUM_PE-1];
    wire [BT_BRAM_ADDR_WIDTH-1:0] max_ref_mod_out [0:NUM_PE-1];
    wire [LOG_NUM_PE-1:0] max_query_pos_in [0:NUM_PE-1];
    wire [LOG_NUM_PE-1:0] max_query_pos_out [0:NUM_PE-1];
    wire [QUERY_LEN_WIDTH-1:0] max_query_mod_in [0:NUM_PE-1];
    wire [QUERY_LEN_WIDTH-1:0] max_query_mod_out [0:NUM_PE-1];
    wire [QUERY_LEN_WIDTH-1:0] max_stripe_num_out [0:NUM_PE-1];
    wire [QUERY_LEN_WIDTH-1:0] max_stripe_num_in [0:NUM_PE-1];
    wire [1:0] max_pe_state_in [0:NUM_PE-1];
    wire [1:0] max_pe_state_out [0:NUM_PE-1];

    wire max_with_y_out [0:NUM_PE-1];
    wire [PE_WIDTH-1:0] global_max_in [0:NUM_PE-1];
    wire [PE_WIDTH-1:0] global_max_out [0:NUM_PE-1];
    wire compute_global_max_in [0:NUM_PE-1];
    wire compute_global_max_out [0:NUM_PE-1];
    wire compute_max_in [0:NUM_PE-1];
    wire compute_max_out [0:NUM_PE-1];
    wire last_in [0:NUM_PE-1];
    wire last_out [0:NUM_PE-1];
    wire stall;

    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_bram_addr[0:NUM_PE-1];
    wire [3:0] bt_bram_data_out[0:NUM_PE-1];

    wire V_intern_fifo_wr_en;
    wire [PE_WIDTH-1:0] V_intern_fifo_wr_data_in;
    wire [PE_WIDTH-1:0] V_intern_fifo_rd_data_out;
  
    wire F_intern_fifo_wr_en;
    wire [PE_WIDTH-1:0] F_intern_fifo_wr_data_in;
    wire [PE_WIDTH-1:0] F_intern_fifo_rd_data_out;
    
    wire E_intern_fifo_wr_en;
    wire [PE_WIDTH-1:0] E_intern_fifo_wr_data_in;
    wire [PE_WIDTH-1:0] E_intern_fifo_rd_data_out;
    
    wire M_intern_fifo_wr_en;
    wire [PE_WIDTH-1:0] M_intern_fifo_wr_data_in;
    wire [PE_WIDTH-1:0] M_intern_fifo_rd_data_out;
    
    wire bt_logic_start;
    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_logic_max_score_addr;
    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_logic_max_score_mod_addr;
    wire [LOG_NUM_PE-1:0] bt_logic_max_score_pe;
    wire [1:0] bt_logic_max_score_pe_state;
    wire [3:0] bt_logic_input_dir;
    wire [3:0] bt_logic_input_dir_diag;
    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_logic_next_addr;
    wire [BT_BRAM_ADDR_WIDTH-1:0] bt_logic_next_addr_diag;
    wire [LOG_NUM_PE-1:0] bt_logic_next_pe;
    wire [LOG_NUM_PE-1:0] bt_logic_next_pe_diag;
    wire bt_logic_addr_valid;
    wire [1:0] bt_logic_dir_out;
    wire [REF_LEN_WIDTH-1:0] bt_logic_H_offset;
    wire [REF_LEN_WIDTH-1:0] bt_logic_V_offset;
    wire bt_logic_dir_valid;
    wire bt_logic_done;
    reg [REF_LEN_WIDTH-1:0] bt_ref_length;
    wire[BT_BRAM_ADDR_WIDTH+LOG_NUM_PE-1:0] bt_logic_num_tb_steps;
    wire [REF_LEN_WIDTH-1:0] bt_start_pos;
    wire [REF_LEN_WIDTH-1:0] bt_next_stop_pos;
    wire [QUERY_LEN_WIDTH-1:0] bt_max_stripe_num;
    wire [REF_LEN_WIDTH-1:0] bt_start_pos_addr;
    wire [REF_LEN_WIDTH-1:0] bt_next_stop_pos_addr;

    wire start_final;
    wire stop_final;
    wire stop;

    wire [QUERY_LEN_WIDTH-1:0] rd_start_pos_counter;
    wire [QUERY_LEN_WIDTH-1:0] wr_start_pos_counter;
    wire wr_start_pos_en;
    wire [REF_LEN_WIDTH-1:0] start_pos_in;
    wire [REF_LEN_WIDTH-1:0] start_pos_out;
    
    reg [REF_LEN_WIDTH-1:0] start_pos_in_reg;
    reg wr_start_pos_en_reg;
    reg state_wr_en_reg;
    reg [QUERY_LEN_WIDTH-1:0] wr_start_pos_counter_reg;

    wire [QUERY_LEN_WIDTH-1:0] rd_stop_pos_counter;
    wire [QUERY_LEN_WIDTH-1:0] wr_stop_pos_counter;
    wire wr_stop_pos_en;
    wire [REF_LEN_WIDTH-1:0] stop_pos_in;
    wire [REF_LEN_WIDTH-1:0] stop_pos_out;
    
    reg [REF_LEN_WIDTH-1:0] stop_pos_in_reg;
    reg wr_stop_pos_en_reg;
    reg [QUERY_LEN_WIDTH-1:0] wr_stop_pos_counter_reg;
    
    reg max_val_for_stop[NUM_PE-1:0];
    reg [PE_WIDTH-1:0] global_max; //max score among all the PEs
    reg [PE_WIDTH-1:0] reg_y; //max score among all the PEs
    reg [PE_WIDTH-1:0] global_max_in_0;
    reg [PE_WIDTH-1:0] F_in_0;
    reg [PE_WIDTH-1:0] E_in_0;
    reg [PE_WIDTH-1:0] V_in_0;
    reg [PE_WIDTH-1:0] M_in_0;
    reg [3:0] T_in_0;
    reg last_query_sent;
    reg init_in_0;
    reg delayed_init_in_0;
    reg delayed_compute_global_max_in_0;
    reg compute_max_in_0;
    reg compute_global_max_in_0;
    reg first_start;
    reg first_element_first_query_block;
    reg [PE_WIDTH-1:0] gap_open;
    reg [PE_WIDTH-1:0] gap_extend;
    reg [1:0]first_element_start; 
    reg [REF_LEN_WIDTH-1:0] first_pe_counter;
    wire [PE_WIDTH-1:0] max_with_y;
    reg stop_prev;
    wire [REF_LEN_WIDTH-1:0] start_pos_pe [NUM_PE-1:0];
    wire [REF_LEN_WIDTH-1:0] V_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
    wire [REF_LEN_WIDTH-1:0] F_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
    wire [REF_LEN_WIDTH-1:0] E_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
    wire [REF_LEN_WIDTH-1:0] M_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
    reg [REF_LEN_WIDTH-1:0] start_pos;
    reg [REF_LEN_WIDTH-1:0] prev_start_pos;
    reg [REF_LEN_WIDTH-1:0] stop_pos;
    reg start_done;
    reg stop_done;
    reg [BT_BRAM_ADDR_WIDTH-1:0] current_position;

    Ascii2Nt ref_ascii2nt
    (
        .ascii(ref_bram_data_in),
        .complement(complement_ref),
        .nt(ref_nt)
    );

    Ascii2Nt query_ascii2nt (
        .ascii(query_bram_data_in),
        .complement(complement_query),
        .nt(query_nt)
    );

    Nt2Param #(
        .PE_WIDTH(PE_WIDTH)
    ) query_nt2param (
        .nt(query_nt),
        .in_param(in_param),
        .out_param(param_out)
    );

    genvar k;
    integer t;

    localparam WAIT=0, READ_PARAM_FIFO=1, SET_PARAM=2, STREAM_REF_START=3, STREAM_REF=4, STREAM_REF_STOP=5, STREAM_CONTINUE=6, STREAM_REF_DONE=7, COMPUTE_MAX_START=8, COMPUTE_MAX_WAIT=9, BT_START=10, BT_WAIT=11, DONE=12;

    generate
        genvar k1;
        genvar k2;
        for (k1=0;k1<LOG_NUM_PE;k1=k1+1) begin: gen_levels
            for (k2=0;k2 < 2**(LOG_NUM_PE - k1 -1); k2=k2+1) begin: gen_nodes
                wire in1;
                wire in2;
                wire out;

                if(k1 == 0) begin
                    assign in1 = max_with_y_out[k2*2];
                    assign in2 = max_with_y_out[k2*2 + 1];
                end
                else begin
                    assign in1 = gen_levels[k1-1].gen_nodes[k2*2].out;
                    assign in2 = gen_levels[k1-1].gen_nodes[k2*2+1].out;
                end

                assign out = in1 | in2;
            end
        end
        assign stop = gen_levels[LOG_NUM_PE-1].gen_nodes[0].out;
    endgenerate


    assign dir = bt_logic_dir_out; 
    assign dir_valid = bt_logic_dir_valid;

    assign param = (curr_query_len > query_length) ? 0 : param_out;
    assign done = (state == DONE);
    assign init_V = (start_pos == 0) ? reg_init_V : ((2'b11) << (PE_WIDTH-2)); //V_intern_fifo_rd_data_out; 
    assign init_M = ((2'b11) << (PE_WIDTH-2));
    assign y = y_in;
    assign max_with_y = global_max - reg_y;

    assign start_final = ~stop_prev & stop;
    assign stop_final = stop_prev & ~stop;
    
    always@(posedge clk) begin
        if(stop == 1 || stop == 0) begin
            stop_prev<=stop;
        end
        else begin  
            stop_prev <= 0;
        end
    end

    always@(posedge clk) begin 
        reg_y <= y_in;
        global_max <= global_max_out[NUM_PE-1];
        if(rst) begin
            start_pos <=0;
            start_pos_in_reg <= 0;
            stop_pos <= ref_length;
            start_done <= 0;
            stop_done <= 1;
        end
        else begin
            if(state == WAIT) begin
                start_pos <=0;
                start_pos_in_reg <= 0;
                stop_pos <= ref_length;
            end
            else if(state == STREAM_REF || state == STREAM_CONTINUE) begin
                //since we store everything, the condition for overlap can now
                //be removed
                if((first_query_block && (start_pos_pe[0]-1)==0) || (~first_query_block && ((start_final == 1 && stop_done == 1) || (init_out[0]==1 && stop ==1 && stop_done==1 && start_pos_pe[0]-1 >=start_pos && start_pos_pe[0]-1 <= stop_pos)))) begin
                    //positions begin from 0
                    
                    start_pos <= start_pos_pe[0]-1;
                    start_pos_in_reg <= start_pos_pe[0]-1;
                    wr_start_pos_en_reg <= 1;
                    stop_done <= 0;
                    start_done <= 1;
                end
                else begin
                    if(start_done==1) begin
                        if(stop_final==1 &&(first_query_block || start_pos_pe[0]>=stop_pos+1)) begin
                            stop_pos <= start_pos_pe[0]-1;
                            stop_pos_in_reg <= start_pos_pe[0]-1;
                            wr_stop_pos_en_reg <= 1;
                            stop_done <= 1;
                            start_done <= 0;
                        end
                        else if(stop==0 && start_pos_pe[0]-1>=stop_pos) begin
                            stop_pos <= start_pos_pe[0]-1;
                            stop_pos_in_reg <= start_pos_pe[0]-1;
                            wr_stop_pos_en_reg <= 1;
                            stop_done <= 1;
                            start_done <= 0;
                        end
                        else if(start_pos_pe[0] >= ref_length) begin
                            stop_pos <= ref_length -1;
                            stop_pos_in_reg <= ref_length-1;
                            wr_stop_pos_en_reg <= 1;
                            stop_done <= 1;
                            start_done <= 0;
                        end
                    end
                    else begin
                        wr_start_pos_en_reg <= 0;
                        wr_stop_pos_en_reg <= 0;
                    end
                end
            end
        end
    end
    
    always @(posedge clk) begin
      if (rst) begin
          set_param <= 0;
          last <= 0;
          first_query_block <= 1'b0;
          first_element_first_query_block <= 1'b0;
          curr_query_len <= 0;
          H_offset <= 0;
          V_offset <= 0;
          init_in_0 <= 0;
          compute_global_max_in_0 <= 0;
          wr_start_pos_counter_reg <= 0;
          wr_stop_pos_counter_reg <= 0;
          ref_max_score_pos <=0;
          query_max_score_pos <= 0;
      end
      else begin
          delayed_init_in_0 <= init_in_0;
          delayed_compute_global_max_in_0 <= compute_global_max_in_0;
          case(state)
              WAIT: begin
                  bt_ref_length <= ref_length;
                  reverse_query <= reverse_query_in;
                  reverse_ref <= reverse_ref_in;
                  complement_query <= complement_query_in;
                  complement_ref <= complement_ref_in;
                  sub_N_in <= in_param[3*PE_WIDTH-1-:PE_WIDTH];
                  gap_open <= in_param[2*PE_WIDTH-1-:PE_WIDTH];
                  gap_extend <= in_param[PE_WIDTH-1:0];
                  first_query_block <= 1'b1;
                  first_start <= 1'b0;
                  last_query_sent <= 0;
                  ref_max_score_pos <=0;
                  query_max_score_pos <= 0;
              end

              READ_PARAM_FIFO: begin
                  wr_start_pos_counter_reg <= 0;
                  wr_stop_pos_counter_reg <= 0;
                  prev_start_pos <= 0;
                  if (reverse_query) begin
                      query_bram_rd_addr <= query_length - 1;
                  end
                  else begin
                      query_bram_rd_addr <= 0;
                  end
                  reg_init_V <= gap_open;
                  if(first_query_block == 1) begin
                      current_position <= 0;
                  end
              end

              SET_PARAM: begin
                  if (reverse_query) begin
                      query_bram_rd_addr <= query_bram_rd_addr - 1;
                  end
                  else begin
                      query_bram_rd_addr <= query_bram_rd_addr + 1;
                  end
                  curr_query_len <= curr_query_len + 1;
                  if (curr_query_len == query_length) begin
                      last_query_sent <= 1;
                  end
                  if (set_param == 0) begin
                      state_wr_en_reg <= 1;
                      set_param <= 1;
                      if ((start_last == 1'b1) && (curr_query_len + 1 == query_length)) begin
                          last <= 1;
                      end
                      else begin
                          last <= 0;
                      end
                  end
                  else begin
                      state_wr_en_reg <= 0;
                      prev_start_pos <= start_pos;
                      set_param <= (set_param << 1);
                      reg_init_V <= reg_init_V + gap_extend;
                      if ((start_last == 1'b1) && (curr_query_len + 1 == query_length)) begin
                          last <= (set_param << 1);
                      end
                      else begin
                          last <= 0;
                      end
                  end
              end

              STREAM_REF_START: begin
                  first_element_start <= 2'd2;
                  set_param <= 0;
                  last <= 0;
                  curr_ref_len <= start_pos +1;
                  if (reverse_ref) begin
                      ref_bram_rd_addr <= ref_length - 1 - start_pos;
                  end
                  else begin
                      ref_bram_rd_addr <= start_pos;
                  end
                  global_max_fifo_rd_en <= 1;
                  first_pe_counter <= start_pos;
              end

              STREAM_REF: begin
                  init_in_0 <= 1;
                  compute_global_max_in_0 <= 1;
                  curr_ref_len <= curr_ref_len + 1;
                  if(first_element_start == 2'd2) begin
                      first_element_start <= 2'd1;
                      first_element_first_query_block <=1;
                  end
                  else if(first_element_start== 2'd1)begin
                      first_element_start <= 0;
                      first_element_first_query_block <= 0;
                  end
                  else begin
                      first_start <= 1'b0;
                      first_element_first_query_block <= 0;
                  end

                  if (reverse_ref) begin
                      ref_bram_rd_addr <= ref_bram_rd_addr - 1;
                  end
                  else begin
                      ref_bram_rd_addr <= ref_bram_rd_addr + 1;
                  end

                  first_pe_counter <= first_pe_counter + 1;
              end

              STREAM_CONTINUE: begin
                  init_in_0 <= 0;              
                  first_query_block <= 0;
                  first_pe_counter <= first_pe_counter + 1;
              end

              STREAM_REF_STOP: begin
                  init_in_0 <= 0;              
                  compute_global_max_in_0 <= 0;
                  first_query_block <= 0;
                  current_position <= current_position + stop_pos - prev_start_pos + 1;
                  wr_start_pos_counter_reg <= wr_start_pos_counter_reg +1;
                  wr_stop_pos_counter_reg <= wr_stop_pos_counter_reg +1;

                  reg_init_V <= reg_init_V + gap_extend;
              end

              BT_WAIT: begin
                  if (bt_logic_done) begin
                      H_offset <= bt_logic_H_offset;
                      V_offset <= bt_logic_V_offset;
                      num_tb_steps <= bt_logic_num_tb_steps;
                  end
              end

              BT_START: begin
                  max_score <= V_out[NUM_PE-1];
                  ref_max_score_pos <= max_ref_mod_out[NUM_PE-1];
                  query_max_score_pos <= (max_query_mod_out[NUM_PE-1] << LOG_NUM_PE) + max_query_pos_out[NUM_PE-1];
              end

          endcase
      end
  end

  assign stall = 0;

  genvar j;
  assign {sub_A_in, sub_C_in, sub_G_in, sub_T_in} = param;
  assign init_E = ((2'b11) << (PE_WIDTH-2)); // hack, rep for -ve infinity

  assign compute_max_in[0] = compute_max_in_0;
  assign last_in[0] = 0;
  assign max_ref_pos_in[0] = 0;
  assign max_ref_mod_in[0] = 0;
  assign max_query_pos_in[0] = 0;
  assign max_query_mod_in[0] = 0;
  assign max_pe_state_in[0] = 0;
  assign max_stripe_num_in[0] = 0;
  assign E_in[0] = E_in_0;
  assign F_in[0] = F_in_0;
  assign V_in[0] = V_in_0;
  assign M_in[0] = M_in_0;
  assign T_in[0] = T_in_0; 
  assign init_in[0] = delayed_init_in_0; 
  assign compute_global_max_in[0] = delayed_compute_global_max_in_0;
  assign global_max_in[0] = global_max_in_0;

  always @(posedge clk) begin
      if (rst) begin
          E_in_0 <= 0;
          F_in_0 <= 0;
          T_in_0 <= 0;
          compute_max_in_0 <= 0;
      end
      else begin          
          //-ve infinity in the first case as the V value is -ve and not 0
          if(first_query_block) begin
              E_in_0 <= (2'b11) << (PE_WIDTH-2);
              F_in_0 <= (2'b11) << (PE_WIDTH-2);
              M_in_0 <= (2'b11) << (PE_WIDTH-2);
              global_max_in_0 <= 0;
              if(state == STREAM_REF_START || state == WAIT || state == READ_PARAM_FIFO || state == SET_PARAM || first_element_start==2'd2) begin
                  V_in_0 <= 0;
              end
              else begin
                  if(first_element_first_query_block == 1'b1) begin
                      V_in_0 <= V_in_0 + gap_open;
                  end
                  else begin
                      V_in_0 <= V_in_0 + gap_extend;
                  end
              end
          end
          else if(state == COMPUTE_MAX_START) begin
              E_in_0 <= E_intern_fifo_rd_data_out;
              F_in_0 <= F_intern_fifo_rd_data_out;
              V_in_0 <= 0;
              global_max_in_0 <= 0;
          end
          else begin
              if(first_pe_counter < stop_pos+2) begin
                  E_in_0 <= E_intern_fifo_rd_data_out;
                  F_in_0 <= F_intern_fifo_rd_data_out;
                  V_in_0 <= V_intern_fifo_rd_data_out;
                  M_in_0 <= M_intern_fifo_rd_data_out;
              end
              else begin
                  E_in_0 <= ((2'b11) << (PE_WIDTH-2));
                  F_in_0 <= ((2'b11) << (PE_WIDTH-2));
                  V_in_0 <= ((2'b11) << (PE_WIDTH-2));
                  M_in_0 <= ((2'b11) << (PE_WIDTH-2));
              end
          end
          T_in_0 <= ref_nt; 
          compute_max_in_0 <= (state == COMPUTE_MAX_START);
      end
  end

  generate
  for (j = 0; j < NUM_PE; j = j+1)
  begin: rst_pe_gen
      always @(posedge clk) begin
          if (rst) begin
              rst_pe[j] <= 1;
          end
          else begin
              rst_pe[j] <= 0;
          end
      end
  end
  endgenerate

  generate
  for (j = 1; j < NUM_PE; j=j+1) 
  begin:systolic_connections
      assign F_in[j] = F_out[j-1]; 
      assign E_in[j] = E_out[j-1]; 
      assign M_in[j] = M_out[j-1]; 
      assign T_in[j] = T_out[j-1]; 
      assign V_in[j] = V_out[j-1]; 
      assign compute_global_max_in[j] = compute_global_max_out[j-1];
      assign compute_max_in[j] = compute_max_out[j-1];
      assign last_in[j] = last_out[j-1];
      assign max_ref_pos_in[j] = max_ref_pos_out[j-1];
      assign max_ref_mod_in[j] = max_ref_mod_out[j-1];
      assign max_query_pos_in[j] = max_query_pos_out[j-1]; 
      assign max_query_mod_in[j] = max_query_mod_out[j-1]; 
      assign max_pe_state_in[j] = max_pe_state_out[j-1];
      assign max_stripe_num_in[j] = max_stripe_num_out[j-1];
      assign init_in[j] = init_out[j-1];
      //to calculate the max of the V calculated by the PEs along the same
      //mod_pos
      assign global_max_in[j] = global_max_out[j-1];
  end
  endgenerate
  
  //generating the PEs
  generate
  for (k = 0; k < NUM_PE; k = k + 1) 
  begin:pe_gen 
  GACTX_NWPE #(
          .WIDTH(PE_WIDTH),
          .REF_WIDTH(REF_LEN_WIDTH),
          .BT_BRAM_ADDR_WIDTH(BT_BRAM_ADDR_WIDTH),
          .QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
          .LOG_NUM_PE(LOG_NUM_PE),
          .PE_ID(k)
      ) inst_nwpe (
          .clk (clk),
          .rst (rst_pe[k]),
          
          .sub_A_in (sub_A_in),
          .sub_C_in (sub_C_in),
          .sub_G_in (sub_G_in),
          .sub_N_in (sub_N_in),
          .sub_T_in (sub_T_in),
          .gap_extend_in (gap_extend),
          .gap_open_in (gap_open),
          .y_in(reg_y),
          .set_param (set_param[k]),
          .start_increment(pe_dir_valid_y_drop[k]),
          .E_in (E_in[k]),
          .F_in (F_in[k]),
          .T_in (T_in[k]),
          .V_in (V_in[k]),
          .M_in (M_in[k]),
          .init_E (init_E),
          .init_V (init_V),
          .init_M (init_M),
          .init_in (init_in[k]),
          .start_transmit_in(start_transmit_in[k]),
          .start_transmit_out(start_transmit_out[k]),
          .start_final(start_final),

          .max_stripe_num_in(max_stripe_num_in[k]),
          .max_stripe_num_out(max_stripe_num_out[k]),
          .max_ref_pos_in (max_ref_pos_in[k]),
          .max_ref_mod_in (max_ref_mod_in[k]),
          .max_query_pos_in (max_query_pos_in[k]),
          .max_query_mod_in (max_query_mod_in[k]),
          .max_pe_state_in (max_pe_state_in[k]),
          .compute_max_in(compute_max_in[k]),
          .last (last[k]),
          .last_in (last_in[k]),
          .global_max_in (global_max_in[k]),
          .max_with_y(max_with_y),
          .compute_global_max_in (compute_global_max_in[k]),

          .start_pos(start_pos),
          .stop_pos(stop_pos),
          .ref_length(ref_length),
          .query_length(query_length),
          .current_position(current_position),

          .global_max_out (global_max_out[k]),
          .max_ref_pos_out (max_ref_pos_out[k]),
          .max_ref_mod_out (max_ref_mod_out[k]),
          .max_query_pos_out (max_query_pos_out[k]),
          .max_query_mod_out (max_query_mod_out[k]),
          .max_pe_state_out (max_pe_state_out[k]),
         
          .last_query_sent(last_query_sent),
          .compute_max_out(compute_max_out[k]),
          .compute_global_max_out (compute_global_max_out[k]),
          .last_out (last_out[k]),
          .E_out (E_out[k]),
          .F_out (F_out[k]),
          .T_out (T_out[k]),
          .V_out (V_out[k]),
          .M_out (M_out[k]),
          .init_out (init_out[k]),
          .dir_addr (pe_dir_addr[k]),
          .dir_valid (pe_dir_valid[k]),
          .dir (pe_dir[k]),
          .max_with_y_out(max_with_y_out[k]),
          .curr_ref_mod(start_pos_pe[k])
      );
  end
  endgenerate

  generate
  for (k = 0; k < NUM_PE; k = k + 1) 
  begin:bram_dir_gen
      assign select_dir_data_in[4*(k+1)-1:4*k] = bt_bram_data_out[k];
      assign bt_bram_addr[k] = (bt_logic_next_pe == k) ? bt_logic_next_addr : bt_logic_next_addr_diag;
      assign pe_dir_valid_y_drop[k] = pe_dir_valid[k] & ((k==0) ? start_transmit_in[1] : start_transmit_out[k]);
  end
  endgenerate

  generate
  for (j = 2; j < NUM_PE; j=j+1) 
  begin:systolic_transmit_connections
      assign start_transmit_in[j] = start_transmit_out[j-1];
  end
  endgenerate

  generate
    
    assign start_transmit_in[1] = ((first_query_block && (start_pos_pe[0]-1)==0) || (~first_query_block && ((start_final == 1 && stop_done == 1 && start_pos_pe[0]-1 < stop_pos+1) || (init_out[0]==1 && stop ==1 && stop_done==1 && start_pos_pe[0]-1 >=start_pos && start_pos_pe[0]-1<=stop_pos)))) | start_done;
  endgenerate
  generate
  for (k = 0; k < NUM_PE; k = k + 1) 
  begin:bram_gen
      DP_BRAM #(
          .ADDR_WIDTH(BT_BRAM_ADDR_WIDTH),
          .DATA_WIDTH(4) //4- number of bits in the direction pointer
      ) bt_dp_bram (
      .clk(clk),
      .waddr(pe_dir_addr[k]),
      .raddr(bt_bram_addr[k]),
      .wr_en(pe_dir_valid[k]),
      .data_in(pe_dir[k]),
      .data_out(bt_bram_data_out[k]));
  end
  endgenerate

  assign wr_start_pos_en = wr_start_pos_en_reg | state_wr_en_reg;
  assign start_pos_in  = start_pos_in_reg;
  assign wr_start_pos_counter = wr_start_pos_counter_reg;

  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(REF_LEN_WIDTH)
  ) start_pos_dpbram
  (
      .clk(clk),

      .raddr(bt_start_pos_addr),
      .waddr(wr_start_pos_counter),

      .wr_en(wr_start_pos_en),
      .data_in(start_pos_in),
      .data_out(bt_start_pos)
  );
  
  assign wr_stop_pos_en = wr_stop_pos_en_reg | state_wr_en_reg;
  assign stop_pos_in  = stop_pos_in_reg;
  assign wr_stop_pos_counter = wr_stop_pos_counter_reg;

  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(REF_LEN_WIDTH)
  ) stop_pos_dpbram
  (
      .clk(clk),

      .raddr(bt_next_stop_pos_addr),
      .waddr(wr_stop_pos_counter),

      .wr_en(wr_stop_pos_en),
      .data_in(stop_pos_in),
      .data_out(bt_next_stop_pos)
  );
  
  assign V_intern_fifo_wr_en = init_out[NUM_PE-1];
  assign V_intern_fifo_wr_data_in = V_out[NUM_PE-1];
  assign V_dpbram_waddr = start_pos_pe[NUM_PE-1]-1;

  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(PE_WIDTH)
  ) V_dpbram
  (
      .clk(clk),

      .raddr(first_pe_counter),
      .waddr(V_dpbram_waddr),

      .wr_en(V_intern_fifo_wr_en),
      .data_in(V_intern_fifo_wr_data_in),
      .data_out(V_intern_fifo_rd_data_out)
  );

  assign M_intern_fifo_wr_en = init_out[NUM_PE-1];// since we store all calculated values/dirs && (start_transmit_out[NUM_PE-1]); 
  assign M_intern_fifo_wr_data_in = M_out[NUM_PE-1];
  assign M_dpbram_waddr = start_pos_pe[NUM_PE-1]-1;

  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(PE_WIDTH)
  ) M_dpbram
  (
      .clk(clk),

      .raddr(first_pe_counter),
      .waddr(M_dpbram_waddr),

      .wr_en(M_intern_fifo_wr_en),
      .data_in(M_intern_fifo_wr_data_in),
      .data_out(M_intern_fifo_rd_data_out)
  );

  assign F_intern_fifo_wr_en = init_out[NUM_PE-1];
  assign F_intern_fifo_wr_data_in = F_out[NUM_PE-1];
  assign F_dpbram_waddr = start_pos_pe[NUM_PE-1]-1;
 
  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(PE_WIDTH)
  ) F_dpbram
  (
      .clk(clk),

      .raddr(first_pe_counter),
      .waddr(F_dpbram_waddr),

      .wr_en(F_intern_fifo_wr_en),
      .data_in(F_intern_fifo_wr_data_in),
      .data_out(F_intern_fifo_rd_data_out)
  );

  assign E_intern_fifo_wr_en = init_out[NUM_PE-1];
  assign E_intern_fifo_wr_data_in = E_out[NUM_PE-1];
  assign E_dpbram_waddr = start_pos_pe[NUM_PE-1]-1;
 
  DP_BRAM #(
      .ADDR_WIDTH(REF_LEN_WIDTH),
      .DATA_WIDTH(PE_WIDTH)
  ) E_dpbram
  (
      .clk(clk),

      .raddr(first_pe_counter),
      .waddr(E_dpbram_waddr),

      .wr_en(E_intern_fifo_wr_en),
      .data_in(E_intern_fifo_wr_data_in),
      .data_out(E_intern_fifo_rd_data_out)
  );
  
  assign bt_logic_start = (state == BT_START);
  assign bt_logic_max_score_addr = max_ref_pos_out[NUM_PE-1];
  assign bt_logic_max_score_mod_addr = max_ref_mod_out[NUM_PE-1];
  assign bt_logic_max_score_pe = max_query_pos_out[NUM_PE-1];
  assign bt_logic_max_score_pe_state = max_pe_state_out[NUM_PE-1]; // ????????
  assign bt_max_stripe_num = max_stripe_num_out[NUM_PE-1];
  

  GACTX_BTLogic #(
      .ADDR_WIDTH(BT_BRAM_ADDR_WIDTH),
      .REF_LEN_WIDTH(REF_LEN_WIDTH),
      .LOG_NUM_PE(LOG_NUM_PE)
  ) inst_bt_logic (
      .clk(clk),
      .rst(rst),
      .start(bt_logic_start),

      .ref_length(bt_ref_length),
      .max_score_addr(bt_logic_max_score_addr),
      .max_score_mod_addr(bt_logic_max_score_mod_addr),
      .max_score_pe(bt_logic_max_score_pe),
      .max_score_pe_state(bt_logic_max_score_pe_state),
      .input_dir(bt_logic_input_dir),
      .input_dir_diag(bt_logic_input_dir_diag),
      .start_pos(bt_start_pos),
      .next_stop_pos(bt_next_stop_pos),
      .max_stripe_num(bt_max_stripe_num),
      .start_pos_addr(bt_start_pos_addr),
      .next_stop_pos_addr(bt_next_stop_pos_addr),

      .next_addr(bt_logic_next_addr),
      .next_pe(bt_logic_next_pe),
      .next_addr_diag(bt_logic_next_addr_diag),
      .next_pe_diag(bt_logic_next_pe_diag),
      .addr_valid(bt_logic_addr_valid),
      .dir(bt_logic_dir_out),
      .dir_valid(bt_logic_dir_valid),
      .H_offset(bt_logic_H_offset),
      .max_H_offset(max_H_offset),
      .V_offset(bt_logic_V_offset),
      .max_V_offset(max_V_offset),
      .num_tb_steps(bt_logic_num_tb_steps),
      .done(bt_logic_done)
  );

  mux_1OfN #( 
      .NUM_PORTS_WIDTH(LOG_NUM_PE),
      .DATA_WIDTH(4)
  ) dir_select (
      .clk(clk),
      .select (bt_logic_next_pe), 
      .data_in (select_dir_data_in),
      .data_out (bt_logic_input_dir)
  );


  mux_1OfN #( 
      .NUM_PORTS_WIDTH(LOG_NUM_PE),
      .DATA_WIDTH(4)
  ) dir_select_diag (
      .clk(clk),
      .select (bt_logic_next_pe_diag), 
      .data_in (select_dir_data_in),
      .data_out (bt_logic_input_dir_diag)
  );

  always @(posedge clk) begin
      if(rst) begin
          state <= WAIT;
      end
      else begin
          case (state)
              WAIT: begin
                  if (start) begin
                      state <= READ_PARAM_FIFO;
                  end
              end

              READ_PARAM_FIFO: begin
                  state <= SET_PARAM;
              end

              SET_PARAM: begin
                  if (set_param[NUM_PE-2] == 1) begin
                      state <= STREAM_REF_START;
                  end
              end

              STREAM_REF_START: begin
                  state <= STREAM_REF;
              end

              STREAM_REF: begin
                  //including the condition of first_query_block because in the
                  //first block the stop_pos = ref_length till the first stop
                  //encountered

                  if(start_done==1) begin
                      if(stop_final==1 &&(first_query_block || start_pos_pe[0]-1>=stop_pos)) begin
                          state <= STREAM_REF_STOP;
                      end
                      else if(stop==0 && start_pos_pe[0]-1>=stop_pos) begin
                          state <= STREAM_REF_STOP;
                      end
                      else if(start_pos_pe[0] >= ref_length) begin
                          state <= STREAM_REF_STOP;
                      end
                      else if (curr_ref_len >= ref_length) begin
                          state <= STREAM_CONTINUE;
                      end
                  end
                  else if(curr_ref_len >= ref_length && stop_done==1) begin
                      state <= STREAM_REF_STOP;
                  end
              end

              STREAM_CONTINUE: begin
                  if(start_done==1) begin
                      if(stop_final==1 &&(first_query_block || start_pos_pe[0]-1>=stop_pos)) begin
                          state <= STREAM_REF_STOP;
                      end
                      else if(stop==0 && start_pos_pe[0]-1>=stop_pos) begin
                          state <= STREAM_REF_STOP;
                      end
                      else if(start_pos_pe[0] >= ref_length) begin
                          state <= STREAM_REF_STOP;
                      end
                  end
              end

              STREAM_REF_STOP: begin
                  if (curr_query_len >= query_length) begin
                      state <= STREAM_REF_DONE;
                  end
                  else begin
                      state <= SET_PARAM;
                  end
              end

              STREAM_REF_DONE: begin
                  state <= COMPUTE_MAX_START;
              end

              COMPUTE_MAX_START: begin
                  state <= COMPUTE_MAX_WAIT;
              end

              COMPUTE_MAX_WAIT: begin
                  if (compute_max_out[NUM_PE-1] == 1'b1) begin
                      state <= BT_START;
                  end
              end

              BT_START: begin
                  state <= BT_WAIT;
              end

              BT_WAIT: begin
                  if (bt_logic_done) begin
                      state <= DONE;
                  end
              end

              DONE: begin
                  state <= WAIT;
              end

          endcase
      end
  end
endmodule

