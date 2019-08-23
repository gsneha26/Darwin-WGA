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

module BSW_Array #(
    parameter NUM_PE = 64,
    parameter PE_WIDTH = 25,
    parameter BLOCK_WIDTH = 3,
    parameter MAX_TILE_SIZE = 2048,
    parameter LOG_MAX_TILE_SIZE = 11
) (
    input wire                                      clk,         
    input wire                                      rst,        

    input wire                                      start,
    output wire                                     ready,
    input wire                                      set_param,
    output wire                                     done,
    input wire                                      clear_done,

    input wire  [13*PE_WIDTH-1:0]                   in_params,
    input wire  [LOG_MAX_TILE_SIZE-1:0]             band_size,
    input wire  [7:0]                               align_fields,

    input wire  [32-1:0]                            tile_id,
    input wire  [32-1:0]                            array_id,

    input wire                                      ref_wr_en,
    input wire                                      query_wr_en,
    
    input wire  [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] ref_addr,
    input wire  [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] query_addr,

    input wire  [8*(2 ** BLOCK_WIDTH)-1:0]          ref_in,
    input wire  [8*(2 ** BLOCK_WIDTH)-1:0]          query_in,

    input wire  [LOG_MAX_TILE_SIZE-1:0]             ref_len,
    input wire  [LOG_MAX_TILE_SIZE-1:0]             query_len,

    output wire [512-1:0]                           tile_output
  );

  parameter LOG_NUM_PE = $clog2(NUM_PE);
  parameter NUM_BLOCK = (2 ** BLOCK_WIDTH);
  
  wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] ref_bram_addr;
  wire [LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0] query_bram_addr;
  
  wire [LOG_MAX_TILE_SIZE-1:0] ref_bram_rd_addr;
  wire [LOG_MAX_TILE_SIZE-1:0] query_bram_rd_addr;
  
  reg  [LOG_MAX_TILE_SIZE-1:0] reg_ref_bram_rd_addr;
  reg  [LOG_MAX_TILE_SIZE-1:0] reg_query_bram_rd_addr;

  reg  [LOG_MAX_TILE_SIZE-1:0] ref_length;
  reg  [LOG_MAX_TILE_SIZE-1:0] query_length;

  wire [8*NUM_BLOCK-1:0] ref_bram_data_out;
  wire [8*NUM_BLOCK-1:0] query_bram_data_out;

  wire [PE_WIDTH-1:0] max_score;
  wire [LOG_MAX_TILE_SIZE-1:0] ref_max_score_pos;
  wire [LOG_MAX_TILE_SIZE-1:0] query_max_score_pos;

  reg  [PE_WIDTH-1:0] score;
  reg  [LOG_MAX_TILE_SIZE-1:0] ref_max_pos;
  reg  [LOG_MAX_TILE_SIZE-1:0] query_max_pos;

  reg  [32-1:0]                     tile_score;
  reg  [32-1:0]                     tile_ref_max_pos;
  reg  [32-1:0]                     tile_query_max_pos;

  reg [13*PE_WIDTH-1:0] reg_in_params;

  wire array_done;
  reg rst_array;

  reg [7:0] ref_array_in;
  reg [7:0] query_array_in;

  reg ref_reverse;
  reg query_reverse;
  reg ref_complement;
  reg query_complement;

  reg [2:0] state;
  localparam READY=1, ARRAY_START=2, ARRAY_PROCESSING=3, BLOCK=4, DONE=5; 
  
  assign ref_bram_addr = (ref_wr_en) ? ref_addr - 1 : ref_bram_rd_addr[LOG_MAX_TILE_SIZE-1:BLOCK_WIDTH];
  assign query_bram_addr = (query_wr_en) ? query_addr - 1 : query_bram_rd_addr[LOG_MAX_TILE_SIZE-1:BLOCK_WIDTH];

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
              query_array_in = query_bram_data_out[8*j+:8];
          end
      end
  end

  always@(posedge clk) begin
      reg_ref_bram_rd_addr <= ref_bram_rd_addr;
      reg_query_bram_rd_addr <= query_bram_rd_addr;
  end
 
  BSW_ArrayTop # (
      .NUM_PE(NUM_PE),
      .LOG_NUM_PE(LOG_NUM_PE),
      .REF_LEN_WIDTH(LOG_MAX_TILE_SIZE),
      .QUERY_LEN_WIDTH(LOG_MAX_TILE_SIZE),
      .PE_WIDTH(PE_WIDTH)
  ) inst_array_top (
      .clk (clk),
      .rst (rst_array),
      .start (array_start),

      .reverse_ref_in(ref_reverse),
      .reverse_query_in(query_reverse),

      .complement_ref_in(ref_complement),
      .complement_query_in(query_complement),

      .in_param(reg_in_params),
      .band_in(band_size),

      .ref_length (ref_length),
      .query_length (query_length),

      .ref_bram_rd_addr(ref_bram_rd_addr),
      .ref_bram_data_in (ref_array_in),

      .query_bram_rd_addr(query_bram_rd_addr),
      .query_bram_data_in (query_array_in),

      .max_score(max_score),
      .ref_max_score_pos(ref_max_score_pos),
      .query_max_score_pos(query_max_score_pos),

      .done(array_done)
  );

  assign done = (state == DONE);
  assign ready = (state == READY) && (~start);
  assign array_start = (state == ARRAY_START);

  always @(posedge clk) begin
      if (rst) begin
          rst_array <= 1;
      end
      else begin
          case (state)
              READY: begin
                  if (set_param) begin
                      rst_array <= 0;
                      reg_in_params <= in_params;
                  end
                  if (start) begin
                      ref_reverse <= align_fields[4];
                      ref_complement <= align_fields[3];
                      query_reverse <= align_fields[2];
                      query_complement <= align_fields[1];
                      ref_length <= ref_len;
                      query_length <= query_len;
                  end
              end
              ARRAY_PROCESSING: begin
                  if (array_done) begin
                      ref_max_pos <= ref_max_score_pos;
                      query_max_pos <= query_max_score_pos;
                      score <= max_score;
                      rst_array <= 1;
                  end
              end
              DONE: begin
                  rst_array <= 0;
              end
          endcase
      end
  end

  always @(posedge clk) begin
      if (rst) begin
          state <= READY;
      end
      else begin
          case (state)
              READY: begin
                  if (start) begin
                      state <= ARRAY_START;
                  end
              end
              ARRAY_START: begin
                  state <= ARRAY_PROCESSING;
              end
              ARRAY_PROCESSING: begin
                  if (array_done) begin
                      state <= BLOCK;
                  end
              end
              BLOCK: begin
                  state <= DONE;
              end
              DONE: begin
                  if (clear_done) begin
                      state <= READY;
                  end
              end
          endcase
      end
  end

 always@(posedge clk) begin
     if(start) begin
        tile_score <= 32'd0;
        tile_ref_max_pos <= 32'd0;
        tile_query_max_pos <= 32'd0;
     end

     if(done) begin
         tile_score <= score;
         tile_ref_max_pos <= ref_max_pos;
         tile_query_max_pos <= query_max_pos;
     end
 end

 assign tile_output = {query_len, ref_len, tile_query_max_pos, tile_ref_max_pos, tile_score, array_id, tile_id};
  
endmodule

