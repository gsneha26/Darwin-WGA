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
module BSW_ArrayTop #(
    parameter NUM_PE = 32,
    parameter LOG_NUM_PE = 5,
    parameter REF_LEN_WIDTH = 10,
    parameter QUERY_LEN_WIDTH = 10,
    parameter PE_WIDTH = 8
)(
    input  clk,         
    input  rst,        
    input  start,
    input  [13*PE_WIDTH-1:0] in_param,

    input reverse_ref_in,
    input reverse_query_in,

    input complement_ref_in,
    input complement_query_in,

    input [REF_LEN_WIDTH-1:0] ref_length,
    input [QUERY_LEN_WIDTH-1:0] query_length,

    input [7:0] ref_bram_data_in,
    input [7:0] query_bram_data_in,

    output reg [REF_LEN_WIDTH-1:0] ref_bram_rd_addr, 
    output reg [QUERY_LEN_WIDTH-1:0] query_bram_rd_addr,

    input [REF_LEN_WIDTH-1:0] band_in, 

    output reg [PE_WIDTH-1:0] max_score,
    output reg [REF_LEN_WIDTH-1:0] ref_max_score_pos,
    output reg [QUERY_LEN_WIDTH-1:0] query_max_score_pos,
    output done
);

  localparam PARAM_WIDTH = 4 * PE_WIDTH;
  localparam BT_BRAM_ADDR_WIDTH = REF_LEN_WIDTH + (QUERY_LEN_WIDTH - LOG_NUM_PE);

  reg first_query_block;

  reg [NUM_PE-1:0] set_param;
  wire [PARAM_WIDTH-1:0] param;
  wire [PARAM_WIDTH-1:0] param_out;

  reg [REF_LEN_WIDTH-1:0] curr_ref_len;
  reg [QUERY_LEN_WIDTH-1:0] curr_query_len;
  
  reg reverse_query, reverse_ref;
  reg complement_query, complement_ref;

  reg rst_pe[NUM_PE-1:0];
  reg [10:0] state;

  wire [3:0] ref_nt; 
  wire [3:0] query_nt; 

  wire [PE_WIDTH-1:0] sub_A_in;
  wire [PE_WIDTH-1:0] sub_C_in;
  wire [PE_WIDTH-1:0] sub_G_in;
  wire [PE_WIDTH-1:0] sub_T_in;
  reg  [PE_WIDTH-1:0] sub_N_in;

  wire [REF_LEN_WIDTH-1:0] band; 
  wire [PE_WIDTH-1:0] F_in  [0:NUM_PE-1];
  wire [2:0] T_in [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] V_in  [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] M_in  [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] E_in  [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] F_out [0:NUM_PE-1];
  wire [2:0] T_out[0:NUM_PE-1];
  wire [PE_WIDTH-1:0] V_out [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] M_out [0:NUM_PE-1];
  wire [PE_WIDTH-1:0] E_out [0:NUM_PE-1];

  reg  [PE_WIDTH-1:0] reg_init_V;
  wire [PE_WIDTH-1:0] init_V;
  wire [PE_WIDTH-1:0] init_M;
  wire [PE_WIDTH-1:0] init_E;

  wire init_in [0:NUM_PE-1];
  wire init_out [0:NUM_PE-1];

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

  wire compute_max_in [0:NUM_PE-1];
  wire compute_max_out [0:NUM_PE-1];

  wire V_intern_fifo_wr_en;
  wire [PE_WIDTH-1:0] V_intern_fifo_wr_data_in;
  wire [PE_WIDTH-1:0] V_intern_fifo_rd_data_out;
  
  wire F_intern_fifo_wr_en;
  wire [PE_WIDTH-1:0] F_intern_fifo_wr_data_in;
  wire [PE_WIDTH-1:0] F_intern_fifo_rd_data_out;
  
  wire M_intern_fifo_wr_en;
  wire [PE_WIDTH-1:0] M_intern_fifo_wr_data_in;
  wire [PE_WIDTH-1:0] M_intern_fifo_rd_data_out;
  
  reg [PE_WIDTH-1:0] F_in_0;
  reg [PE_WIDTH-1:0] V_in_0;
  reg [PE_WIDTH-1:0] M_in_0;
  reg [3:0] T_in_0;
  reg last_query_sent;
  reg init_in_0;
  reg delayed_init_in_0;
  reg compute_max_in_0;
  reg first_element_first_query_block;
  reg [PE_WIDTH-1:0] gap_open;
  reg [PE_WIDTH-1:0] gap_extend;
  reg [REF_LEN_WIDTH-1:0] first_pe_counter;
  wire [REF_LEN_WIDTH-1:0] start_pos_pe [NUM_PE-1:0];
  wire [REF_LEN_WIDTH-1:0] V_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
  wire [REF_LEN_WIDTH-1:0] F_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
  wire [REF_LEN_WIDTH-1:0] M_dpbram_waddr; //   start_pos_pe [NUM_PE-1:0];
  reg [REF_LEN_WIDTH-1:0] start_pos;
  reg [REF_LEN_WIDTH-1:0] stop_pos;
  reg [REF_LEN_WIDTH-1:0] prev_stop_pos;
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

  localparam WAIT=0, READ_PARAM_FIFO=1, SET_PARAM=2, STREAM_REF_START=4, STREAM_REF=8, STREAM_REF_STOP=16, STREAM_CONTINUE=32, STREAM_REF_DONE=64, COMPUTE_MAX_START=128, COMPUTE_MAX_WAIT=256, DONE=512, SET_PARAM0=1024;

  assign param = (curr_query_len > query_length) ? 0 : param_out;
  assign done = (state == DONE);
  assign init_V = reg_init_V;
  assign init_M = ((2'b11) << (PE_WIDTH-2)); // reg_init_V;
  assign band = band_in;
  
  always @(posedge clk) begin
      if (rst) begin
          set_param <= 0;
          first_query_block <= 1'b0;
          first_element_first_query_block <= 1'b0;
          curr_query_len <= 0;
          init_in_0 <= 0;
          max_score <= 0;
          ref_max_score_pos <= 0;
          query_max_score_pos <= 0;
          compute_max_in_0 <= 0;
      end
      else begin
          delayed_init_in_0 <= init_in_0;
          case(state)
              WAIT: begin
                  reverse_query <= reverse_query_in;
                  reverse_ref <= reverse_ref_in;
                  complement_query <= complement_query_in;
                  complement_ref <= complement_ref_in;
                  sub_N_in <= in_param[3*PE_WIDTH-1-:PE_WIDTH];
                  gap_open <= in_param[2*PE_WIDTH-1-:PE_WIDTH];
                  gap_extend <= in_param[PE_WIDTH-1:0];
                  first_query_block <= 1'b1;
                  last_query_sent <= 0;
                  start_pos <= 0;
                  stop_pos <= band+NUM_PE-1;
                  compute_max_in_0 <= 0;
              end

              READ_PARAM_FIFO: begin
                  if (reverse_query) begin
                      query_bram_rd_addr <= query_length - 1;
                  end
                  else begin
                      query_bram_rd_addr <= 0;
                  end
                  if(first_query_block == 1) begin
                      current_position <= 1;
                  end
              end

              SET_PARAM0: begin
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

                  set_param <= 1;
                  reg_init_V <= gap_open;

                  curr_ref_len <= start_pos +1;

                  if (reverse_ref) begin
                      ref_bram_rd_addr <= ref_length - 1;
                  end
                  else begin
                      ref_bram_rd_addr <= start_pos;
                  end
                  
                  first_pe_counter <= start_pos;
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

                  set_param <= (set_param << 1);
                  reg_init_V <= reg_init_V + gap_extend;

                  init_in_0 <= 1;
                  curr_ref_len <= curr_ref_len + 1;

                  if (reverse_ref) begin
                      ref_bram_rd_addr <= ref_bram_rd_addr - 1;
                  end
                  else begin
                      ref_bram_rd_addr <= ref_bram_rd_addr + 1;
                  end

                  first_pe_counter <= first_pe_counter + 1;
              end

              STREAM_REF: begin
                  set_param <= 0;
                  curr_ref_len <= curr_ref_len + 1;

                  if (reverse_ref) begin
                      ref_bram_rd_addr <= ref_bram_rd_addr - 1;
                  end
                  else begin
                      ref_bram_rd_addr <= ref_bram_rd_addr + 1;
                  end

                  first_pe_counter <= first_pe_counter + 1;
              end

              STREAM_REF_STOP: begin
                  init_in_0 <= 0;              
                  first_query_block <= 0;
                  current_position <= current_position + stop_pos - start_pos+1;
                  prev_stop_pos <= stop_pos;
                  reg_init_V <= reg_init_V + gap_extend;
                  if(curr_query_len <= band) begin
                      start_pos <= 0;
                  end
                  else begin
                      start_pos <= curr_query_len - band;
                  end

                  if(curr_query_len + NUM_PE-1 >= query_length-band) begin
                      stop_pos <= ref_length;
                  end
                  else begin
                      stop_pos <= curr_query_len + NUM_PE -1 +band;
                  end
              end

              COMPUTE_MAX_START: begin
                  compute_max_in_0 <= 1;
              end

              COMPUTE_MAX_WAIT: begin
                  compute_max_in_0 <= 0;
                  if (compute_max_out[NUM_PE-1] == 1'b1) begin
                      max_score <= V_out[NUM_PE-1];
                      ref_max_score_pos <= max_ref_mod_out[NUM_PE-1];
                      query_max_score_pos <= (max_query_mod_out[NUM_PE-1] << LOG_NUM_PE) + max_query_pos_out[NUM_PE-1];
                  end
              end
          endcase
      end
  end

  always @(posedge clk) begin
      if (rst) begin
          F_in_0 <= 0;
          V_in_0 <= 0;
          T_in_0 <= 0;
      end
      else begin          
          //-ve infinity in the first case as the V value is -ve and not 0
          if(first_query_block) begin
              F_in_0 <= (2'b11) << (PE_WIDTH-2);
              V_in_0 <= 0;
              M_in_0 <= 0;
          end
          else if(state == COMPUTE_MAX_START) begin
              F_in_0 <= F_intern_fifo_rd_data_out;
              V_in_0 <= 0;
              M_in_0 <= 0;
          end
          else begin
              if(first_pe_counter <= prev_stop_pos) begin
                  F_in_0 <= F_intern_fifo_rd_data_out;
                  V_in_0 <= V_intern_fifo_rd_data_out;
                  M_in_0 <= M_intern_fifo_rd_data_out;
              end
              else begin
                  F_in_0 <= ((2'b11) << (PE_WIDTH-2));
                  V_in_0 <= ((2'b11) << (PE_WIDTH-2));
                  M_in_0 <= ((2'b11) << (PE_WIDTH-2));
              end
          end
          T_in_0 <= ref_nt; 
      end
  end

  always @(posedge clk) begin
      if (rst) begin
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
                  state <= SET_PARAM0;
              end

              SET_PARAM0: begin
                  if (set_param[NUM_PE-2] == 1) begin
                      state <= STREAM_REF_START;
                  end
                  else begin
                      state <= SET_PARAM;
                  end
              end

              SET_PARAM: begin
                  if (set_param[NUM_PE-2] == 1) begin
                      state <= STREAM_REF;
                  end
              end

              STREAM_REF: begin
                  if(curr_ref_len >= stop_pos+1) begin
                      state <= STREAM_REF_STOP;
                  end
              end

              STREAM_REF_STOP: begin
                  if (curr_query_len >= query_length) begin
                      state <= STREAM_REF_DONE;
                  end
                  else begin
                      state <= SET_PARAM0;
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
                      state <= DONE;
                  end
              end

              DONE: begin
                  state <= WAIT;
              end
          endcase
      end
  end

  assign {sub_A_in, sub_C_in, sub_G_in, sub_T_in} = param;
  assign init_E = ((2'b11) << (PE_WIDTH-2)); // hack, rep for -ve infinity

  assign compute_max_in[0] = compute_max_in_0;
  assign max_ref_pos_in[0] = 0;
  assign max_ref_mod_in[0] = 0;
  assign max_query_pos_in[0] = 0;
  assign max_query_mod_in[0] = 0;
  assign max_stripe_num_in[0] = 0;
  assign F_in[0] = F_in_0;
  assign V_in[0] = V_in_0;
  assign M_in[0] = M_in_0;
  assign T_in[0] = T_in_0; 
  assign init_in[0] = delayed_init_in_0; 

  genvar j;
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
      assign M_in[j] = M_out[j-1]; 
      assign T_in[j] = T_out[j-1]; 
      assign V_in[j] = V_out[j-1]; 
      assign compute_max_in[j] = compute_max_out[j-1];
      assign max_ref_pos_in[j] = max_ref_pos_out[j-1];
      assign max_ref_mod_in[j] = max_ref_mod_out[j-1];
      assign max_query_pos_in[j] = max_query_pos_out[j-1]; 
      assign max_query_mod_in[j] = max_query_mod_out[j-1]; 
      assign max_stripe_num_in[j] = max_stripe_num_out[j-1];
      assign init_in[j] = init_out[j-1];
  end
  endgenerate
  
  //generating the PEs
  genvar k;
  generate
  for (k = 0; k < NUM_PE; k = k + 1) 
  begin:pe_gen 
  BSW_PE #(
          .WIDTH(PE_WIDTH),
          .REF_LEN_WIDTH(REF_LEN_WIDTH),
          .BT_BRAM_ADDR_WIDTH(BT_BRAM_ADDR_WIDTH),
          .QUERY_LEN_WIDTH(QUERY_LEN_WIDTH),
          .LOG_NUM_PE(LOG_NUM_PE),
          .PE_ID(k)
      ) inst_pe (
          .clk (clk),
          .rst (rst_pe[k]),
          
          .sub_A_in (sub_A_in),
          .sub_C_in (sub_C_in),
          .sub_G_in (sub_G_in),
          .sub_N_in (sub_N_in),
          .sub_T_in (sub_T_in),
          .gap_extend_in (gap_extend),
          .gap_open_in (gap_open),
          .set_param (set_param[k]),
          .F_in (F_in[k]),
          .T_in (T_in[k]),
          .V_in (V_in[k]),
          .M_in (M_in[k]),
          .init_E (init_E),
          .init_V (init_V),
          .init_M (init_M),
          .init_in (init_in[k]),

          .max_stripe_num_in(max_stripe_num_in[k]),
          .max_stripe_num_out(max_stripe_num_out[k]),
          .max_ref_pos_in (max_ref_pos_in[k]),
          .max_ref_mod_in (max_ref_mod_in[k]),
          .max_query_pos_in (max_query_pos_in[k]),
          .max_query_mod_in (max_query_mod_in[k]),
          .compute_max_in(compute_max_in[k]),

          .start_pos(start_pos),
          .ref_length(ref_length),
          .current_position(current_position),

          .max_ref_pos_out (max_ref_pos_out[k]),
          .max_ref_mod_out (max_ref_mod_out[k]),
          .max_query_pos_out (max_query_pos_out[k]),
          .max_query_mod_out (max_query_mod_out[k]),
         
          .last_query_sent(last_query_sent),
          .compute_max_out(compute_max_out[k]),
          .E_out (E_out[k]),
          .F_out (F_out[k]),
          .T_out (T_out[k]),
          .V_out (V_out[k]),
          .M_out (M_out[k]),
          .init_out (init_out[k]),
          .curr_ref_mod(start_pos_pe[k])
      );
  end
  endgenerate

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

  assign M_intern_fifo_wr_en = init_out[NUM_PE-1]; 
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

endmodule

