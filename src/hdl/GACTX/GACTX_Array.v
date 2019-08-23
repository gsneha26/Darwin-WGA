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

module GACTX_Array #(
    parameter PE_WIDTH = 25,
    parameter BLOCK_WIDTH = 3,
    parameter MAX_TILE_SIZE = 2048,
	parameter LOG_MAX_TILE_SIZE = 11,
    parameter NUM_PE = 64,
    parameter NUM_DIR_BLOCK = 32,
    parameter DIR_BRAM_ADDR_WIDTH = 14
) (
    input wire  clk,         
    input wire  rst,        

    input wire [13*PE_WIDTH-1:0] in_params,
    input wire [PE_WIDTH-1:0] y_in,
    input wire set_params,
    input wire [8*(2 ** BLOCK_WIDTH)-1:0] query_in,
    input wire [8*(2 ** BLOCK_WIDTH)-1:0] ref_in,
    
    input wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] ref_addr_in,
    input wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] query_addr_in,
    input wire ref_wr_en,
    input wire query_wr_en,

    input wire [LOG_MAX_TILE_SIZE:0] max_tb_steps,
    input wire [LOG_MAX_TILE_SIZE-1:0] ref_len,
    input wire [LOG_MAX_TILE_SIZE-1:0] query_len,

    input wire [7:0] align_fields,

    output wire ready,
    input wire start,
    output wire done,
    input wire clear_done,

    output reg [PE_WIDTH-1:0] tile_score,
    output reg [LOG_MAX_TILE_SIZE-1:0] ref_max_pos,
    output reg [LOG_MAX_TILE_SIZE-1:0] query_max_pos,
    output reg [2*LOG_MAX_TILE_SIZE-1:0] num_tb_steps,
    output reg [LOG_MAX_TILE_SIZE-1:0] num_ref_bases,
    output reg [LOG_MAX_TILE_SIZE-1:0] num_query_bases,

    input wire [DIR_BRAM_ADDR_WIDTH-1:0] dir_rd_addr,
    output reg [DIR_BRAM_ADDR_WIDTH-1:0] dir_total_count,
    output wire [2*NUM_DIR_BLOCK-1:0] dir_data_out,
    output wire dir_valid,
    output wire [1:0] dir
  );

  parameter LOG_NUM_PE = $clog2(NUM_PE);
  parameter NUM_BLOCK = (2 ** BLOCK_WIDTH);
  
  wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] ref_bram_addr;
  wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] query_bram_addr;
  
  wire [LOG_MAX_TILE_SIZE-1:0] ref_bram_rd_addr;
  wire [LOG_MAX_TILE_SIZE-1:0] query_bram_rd_addr;
  
  reg [LOG_MAX_TILE_SIZE-1:0] reg_ref_bram_rd_addr;
  reg [LOG_MAX_TILE_SIZE-1:0] reg_query_bram_rd_addr;

  reg [LOG_MAX_TILE_SIZE-1:0] ref_length;
  reg [LOG_MAX_TILE_SIZE-1:0] query_length;

  wire [8*NUM_BLOCK-1:0] ref_bram_data_out;
  wire [8*NUM_BLOCK-1:0] query_bram_data_out;

  reg [LOG_MAX_TILE_SIZE-1:0] max_H_offset;
  reg [LOG_MAX_TILE_SIZE-1:0] max_V_offset;

  wire [LOG_MAX_TILE_SIZE-1:0] ref_max_score_pos;
  wire [LOG_MAX_TILE_SIZE-1:0] query_max_score_pos;

  wire [PE_WIDTH-1:0] max_score;
  wire [LOG_MAX_TILE_SIZE-1:0] H_offset;
  wire [LOG_MAX_TILE_SIZE-1:0] V_offset;

  wire [2*LOG_MAX_TILE_SIZE-1:0] array_num_tb_steps;

  reg [13*PE_WIDTH-1:0] reg_in_params;

  wire [PE_WIDTH-1:0] y;
  reg [7:0] dir_count;
  reg dir_wr_en;
  reg [2*NUM_DIR_BLOCK-1:0] dir_data_in;
  wire [DIR_BRAM_ADDR_WIDTH-1:0] dir_wr_addr;

  wire array_done;
  reg rst_array;

  reg [2:0] state;
  reg [2:0] next_state;

  localparam READY=1, ARRAY_START=2, ARRAY_PROCESSING=3, BLOCK=4, DONE=5; 
  
  assign y = y_in;
  assign ref_bram_addr = (ref_wr_en) ? ref_addr_in - 1 : ref_bram_rd_addr[LOG_MAX_TILE_SIZE-1:BLOCK_WIDTH];
  assign query_bram_addr = (query_wr_en) ? query_addr_in - 1 : query_bram_rd_addr[LOG_MAX_TILE_SIZE-1:BLOCK_WIDTH];

  BRAM #(
      .ADDR_WIDTH(LOG_MAX_TILE_SIZE-BLOCK_WIDTH),
      .DATA_WIDTH(8*NUM_BLOCK)
  ) ref_bram (
      .clk(clk),
      .addr(ref_bram_addr),
      .write_en(ref_wr_en),
      .data_in(ref_in),
      .data_out(ref_bram_data_out)
  );

  BRAM #(
      .ADDR_WIDTH(LOG_MAX_TILE_SIZE-BLOCK_WIDTH),
      .DATA_WIDTH(8*NUM_BLOCK)
  ) query_bram (
      .clk(clk),
      .addr(query_bram_addr),
      .write_en(query_wr_en),
      .data_in(query_in),
      .data_out(query_bram_data_out)
  );

  DP_BRAM #(
      .DATA_WIDTH(2*NUM_DIR_BLOCK),
      .ADDR_WIDTH(DIR_BRAM_ADDR_WIDTH)
  ) dir_bram (
      .clk(clk),

      .raddr (dir_rd_addr),
      .wr_en (dir_wr_en),
      .waddr (dir_wr_addr),

      .data_in (dir_data_in),
      .data_out (dir_data_out)
  );
  
  reg [7:0] ref_array_in;
  reg [7:0] query_array_in;

  reg ref_complement;
  reg query_complement;
  reg ref_reverse;
  reg query_reverse;
  reg start_last; // 1 - start traceback from bottom right, 0 - start from max score cell 

  integer i, j;
  always @(*) begin
      ref_array_in = 0;
      for (i = 0; i < NUM_BLOCK; i=i+1) 
      begin:m
          if (reg_ref_bram_rd_addr[BLOCK_WIDTH-1:0] == i) begin
              ref_array_in = ref_bram_data_out[8*i+:8];
          end
      end
  end
  
  always @(*) begin
      query_array_in = 0;
      for (j = 0; j < NUM_BLOCK; j=j+1) 
      begin:n
          if (reg_query_bram_rd_addr[BLOCK_WIDTH-1:0] == j) begin
//              query_array_in = (query_bram_rd_addr <= query_length) ? query_bram_data_out[8*j+:8] : 0;
              query_array_in = query_bram_data_out[8*j+:8];
          end
      end
  end

  always@(posedge clk) begin
      reg_ref_bram_rd_addr <= ref_bram_rd_addr;
      reg_query_bram_rd_addr <= query_bram_rd_addr;
  end
 
  GACTX_ArrayTop # (
      .NUM_PE(NUM_PE),
      .LOG_NUM_PE(LOG_NUM_PE),
      .REF_LEN_WIDTH(LOG_MAX_TILE_SIZE),
      .QUERY_LEN_WIDTH(LOG_MAX_TILE_SIZE),
      .PE_WIDTH(PE_WIDTH),
      .PARAM_ADDR_WIDTH(LOG_MAX_TILE_SIZE)
  ) inst_array_top (
      .clk (clk),
      .rst (rst_array),
      .start (array_start),

      .reverse_ref_in(ref_reverse),
      .reverse_query_in(query_reverse),

      .complement_ref_in(ref_complement),
      .complement_query_in(query_complement),

      .in_param(reg_in_params),
      .y_in(y),

      .ref_length (ref_length),
      .query_length (query_length),

      .ref_bram_rd_addr(ref_bram_rd_addr),
      .ref_bram_data_in (ref_array_in),

      .query_bram_rd_addr(query_bram_rd_addr),
      .query_bram_data_in (query_array_in),

      .start_last(start_last),

      .max_score(max_score),
      .H_offset(H_offset),
      .max_H_offset(max_H_offset),
      .V_offset(V_offset),
      .max_V_offset(max_V_offset),

      .num_tb_steps(array_num_tb_steps),

      .ref_max_score_pos(ref_max_score_pos),
      .query_max_score_pos(query_max_score_pos),

      .dir(dir),
      .dir_valid(dir_valid),

      .done(array_done)
  );


  assign done = (state == DONE);
  assign ready = (state == READY) && (~start);
  assign array_start = (state == ARRAY_START);
  assign dir_wr_addr = (dir_total_count - 1);

  always @(posedge clk) begin
      if (rst) begin
          dir_wr_en <= 0;
          rst_array <= 1;
          state <= READY;
      end
      else begin
          state <= next_state;
          if (state == READY) begin
              if (set_params) begin
                  rst_array <= 0;
                  reg_in_params <= in_params;
//                  reg_y <= y_in;
              end
              if (start) begin
                  ref_reverse <= align_fields[4];
                  ref_complement <= align_fields[3];
                  query_reverse <= align_fields[2];
                  query_complement <= align_fields[1];
                  start_last <= align_fields[0];
                  max_H_offset <= max_tb_steps;
                  max_V_offset <= max_tb_steps;
                  ref_length <= ref_len;
                  query_length <= query_len;
                  dir_total_count <= 0;
                  dir_count <= 0;
                  dir_wr_en <= 0;
              end
          end
          if (state == ARRAY_PROCESSING) begin
              if (dir_valid) begin
                  // TODO
                  if (dir_count == 0) begin
                      dir_data_in <= dir; 
                  end
                  else begin
                      dir_data_in <= (dir << 2*dir_count) + dir_data_in;
                  end
                  if (dir_count == NUM_DIR_BLOCK-1) begin
                      dir_wr_en <= 1;
                      dir_total_count <= dir_total_count + 1;
//                      dir_count <= dir_count + 1;
                      dir_count <= 0;
                  end
                  else begin
                      dir_wr_en <= 0;
                      dir_count <= dir_count + 1;
                  end
              end
              else if (array_done) begin
                  ref_max_pos <= ref_max_score_pos;
                  query_max_pos <= query_max_score_pos;
                  num_ref_bases <= H_offset;
                  num_query_bases <= V_offset;
                  num_tb_steps <= array_num_tb_steps;
                  tile_score <= max_score;
                  rst_array <= 1;
                  if (dir_count > 0) begin
                      dir_wr_en <= 1;
                      dir_total_count <= dir_total_count + 1;
                      dir_count <= dir_count + 1;
                  end
                  else begin
                      dir_wr_en <= 0;
                  end
              end
              else begin
                  dir_wr_en <= 0;
              end
          end
          if (state == BLOCK) begin
              dir_wr_en <= 0;
          end
          if (state == DONE) begin
              rst_array <= 0;
              dir_wr_en <= 0;
          end
      end
  end

  always @(*) 
  begin
      next_state = state;
      case (state)
          READY: begin
              if (start) begin
                  next_state = ARRAY_START;
              end
          end
          ARRAY_START: begin
              next_state = ARRAY_PROCESSING;
          end
          ARRAY_PROCESSING: begin
              if (array_done) begin
                  next_state = BLOCK;
              end
          end
          BLOCK: begin
              next_state = DONE;
          end
          DONE: begin
              if (clear_done) begin
                  next_state = READY;
              end
          end
      endcase
  end
  
endmodule

