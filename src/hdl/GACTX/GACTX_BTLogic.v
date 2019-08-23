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
module GACTX_BTLogic #(
  parameter ADDR_WIDTH = 20,
  parameter REF_LEN_WIDTH = 12,
  parameter LOG_NUM_PE = 6
)
(
    input clk,
    input rst,
    input start,

    input [REF_LEN_WIDTH-1:0] ref_length,
    input [ADDR_WIDTH-1:0] max_score_mod_addr,
    input [ADDR_WIDTH-1:0] max_score_addr,
    input [LOG_NUM_PE-1:0] max_score_pe,
    input [1:0] max_score_pe_state,
    input [3:0] input_dir,
    input [3:0] input_dir_diag,
    input [REF_LEN_WIDTH-1:0] start_pos,
    input [REF_LEN_WIDTH-1:0] next_stop_pos,
    input [REF_LEN_WIDTH-1:0] max_stripe_num,


    output reg [ADDR_WIDTH-1:0] next_addr,
    output reg [LOG_NUM_PE-1:0] next_pe,
    output wire [ADDR_WIDTH-1:0] next_addr_diag,
    output wire [LOG_NUM_PE-1:0] next_pe_diag,
    output wire addr_valid,
    output wire [1:0] dir,
    output wire dir_valid,
    output wire [REF_LEN_WIDTH-1:0] start_pos_addr,
    output wire [REF_LEN_WIDTH-1:0] next_stop_pos_addr,
    output reg [REF_LEN_WIDTH-1:0] H_offset,
    input [REF_LEN_WIDTH-1:0] max_H_offset,
    output reg [REF_LEN_WIDTH-1:0] V_offset,
    input [REF_LEN_WIDTH-1:0] max_V_offset,
    output reg [ADDR_WIDTH+LOG_NUM_PE-1:0] num_tb_steps,
    output done
);

  localparam MAX_PE = (2**LOG_NUM_PE) - 1;

  reg [REF_LEN_WIDTH-1:0] max_stripe;
  reg [ADDR_WIDTH-1:0] mod_count;
  reg [1:0] next_pe_state;

  reg [2:0] state;
  reg [2:0] next_state;
  reg final_H;
  reg final_V;
  reg stripe_change;
  reg stripe0;
  reg [REF_LEN_WIDTH-1:0] curr_start_pos;
  reg [REF_LEN_WIDTH-1:0] curr_stop_pos;
  reg [REF_LEN_WIDTH-1:0] position_addr;

  localparam WAIT=0, BLOCK0=1, BLOCK1=2, BLOCK2=3, CALC=4, DONE=5;
  localparam ZERO=0, M=3, V=1, H=2;

  wire [LOG_NUM_PE-1:0] next_pe_decr_mod;
  wire [ADDR_WIDTH-1:0] next_addr_mod;
  
  wire [REF_LEN_WIDTH-1:0] next_V_offset;
  wire [REF_LEN_WIDTH-1:0] next_H_offset;

  assign done = (state == DONE);
  assign dir_valid = (state == CALC) && (dir != 0);
  assign addr_valid = (next_state == CALC);
  assign dir = next_pe_state;

  assign start_pos_addr = position_addr;
  assign next_stop_pos_addr = position_addr;

  assign next_pe_decr_mod = (next_pe == 0) ? MAX_PE : (next_pe - 1);
  assign next_addr_mod = (next_pe == 0) ? (next_addr - next_stop_pos + start_pos -2) : (next_addr - 1);
  
  assign next_addr_diag = next_addr_mod;
  assign next_pe_diag = next_pe_decr_mod;
  
  assign next_V_offset = ((next_pe_state == M) || (next_pe_state == V)) ? (V_offset + 1) : V_offset;
  assign next_H_offset = ((next_pe_state == M) || (next_pe_state == H)) ? (H_offset + 1) : H_offset;

  always @(posedge clk) begin
      curr_start_pos <= start_pos;
      curr_stop_pos <= next_stop_pos;
  end

  always @(posedge clk) begin
      if (rst) begin
          state <= WAIT;
      end
      else begin
          state <= next_state;
          case (state)
              WAIT: begin
                  stripe0 <= 0;
                  max_stripe <= max_stripe_num;
                  mod_count <= max_score_mod_addr;
                  next_addr <= max_score_addr;
                  next_pe <= max_score_pe; 
                  next_pe_state <= max_score_pe_state;
                  H_offset <= 0;
                  V_offset <= 0;
                  num_tb_steps <= 0;
                  final_H <= 0;
                  final_V <= 0;
                  stripe_change <= 0;
                  if(max_stripe_num > 0) begin
                      position_addr <= max_stripe_num - 1;
                  end
                  else begin
                      stripe0 <= 1;
                      position_addr <= 0;
                  end
              end
              BLOCK0: begin
              end
              BLOCK1: begin
              end
              BLOCK2: begin
              end
              CALC: begin
                  H_offset <= next_H_offset;
                  V_offset <= next_V_offset;
                  num_tb_steps <= num_tb_steps + (dir != 0);

                  //////////////////////////////////////////////////////////////////
                  if (next_pe_state == M) begin

                      //for moving onto the next stripe
                      //When it is PE0, new start and stop  values need to
                      //be requested from the BRAMs in the Array module         
                      if (next_pe == 0 && position_addr > 0) begin
                          position_addr <= position_addr - 1;
                      end
                      else if(next_pe == 0 && position_addr == 0) begin
                          stripe0 <= 1;
                      end

                      //end of the traceback (NW)
                      if(next_pe==0 && next_addr ==0) begin
                          next_pe_state <= ZERO;
                      end

                      else begin
                          //on the first column, then go vertically
                          if(mod_count == 0 && ((stripe0 == 1 && next_pe > 0) || (stripe0 == 0))) begin
                              final_V <= 1;
                              next_pe_state <= V;
                              if (next_pe == 0 && stripe0 == 0) begin
                                  next_pe <= MAX_PE;
                                  next_addr <= next_addr - curr_stop_pos + curr_start_pos - 1;
                              end
                              else begin
                                  next_pe <= next_pe - 1;
                              end
                          end
                          
                          //on the first stripe, then go horizontally
                          else if ((next_pe==0 && mod_count > 0) && (next_addr < curr_stop_pos) && (stripe0 == 1)) begin
                              next_pe_state <= H;
                              final_H <= 1;
                              mod_count <= mod_count - 1;
                              next_addr <= next_addr - 1;
                          end

                          else begin 
                              if (next_pe == 0 && stripe0 == 0) begin
                                  next_addr <= next_addr - curr_stop_pos + curr_start_pos - 2;
                                  next_pe <= MAX_PE;
                              end
                              else begin
                                  next_addr <= next_addr - 1;
                                  next_pe <= next_pe - 1;
                              end
                              next_pe_state <= input_dir_diag[1:0];
                              mod_count <= mod_count - 1;
                          end
                      end
                  end
                  /////////////////////////////////////////////////////////////////////////////
                  else if (next_pe_state == V) begin

                      //for moving onto the next stripe
                      //When it is PE0, new start and stop  values need to
                      //be requested from the BRAMs in the Array module         
                      if (next_pe == 0 && position_addr > 0) begin
                          position_addr <= position_addr - 1;
                      end
                      else if(next_pe == 0 && position_addr == 0) begin
                          stripe0 <= 1;
                      end

                      //end of the traceback (NW)
                      if(next_pe==0 && next_addr==0) begin
                          next_pe_state <= ZERO;
                          final_V <= 0;
                      end

                      else begin
                          
                          //in PE#0 in the first stripe
                          if ((next_pe == 0 && mod_count > 0) && (next_addr < curr_stop_pos) && (stripe0 == 1)) begin
                              next_pe_state <= H; 
                              final_H <= 1;
                          end
                          else begin
                              //choosing the next PE
                              if (next_pe == 0 && stripe0 == 0) begin
                                  next_pe <= MAX_PE;
                                  next_addr <= next_addr - curr_stop_pos + curr_start_pos -1;
                              end
                              else begin
                                  next_pe <= next_pe - 1;
                              end
                              if(input_dir[2] == 0 || final_V) begin
                                  next_pe_state <= V;
                              end
                              else begin
                                  next_pe_state <= M;
                              end
                          end
                      end
                  end
                  /////////////////////////////////////////////////////////////////////////////
                  else if (next_pe_state == H) begin
                      if(next_addr == 0 && next_pe == 0) begin
                          next_pe_state <= ZERO;
                          final_H <= 0;
                      end
                      else begin
                          if(mod_count == 0 && ((stripe0 == 1 && next_pe > 0) || (stripe0 == 0))) begin
                              final_V <= 1;
                              next_pe_state <= V;
                          end
                          else begin
                              if (input_dir[3] == 0 || (final_H && next_addr > 0)) begin
                                  next_pe_state <= H;
                              end
                              else begin
                                  next_pe_state <= M;
                              end
                          end
                          mod_count <= mod_count - 1;
                          next_addr <= next_addr - 1;
                      end
                  end
              end
             DONE: begin
             end
         endcase
     end
  end

  always @(*) 
  begin
      next_state = state;
      case (state)
          WAIT:
              if (start)
                  next_state = BLOCK0;
          BLOCK0:
              next_state = BLOCK1;
          BLOCK1:
              next_state = BLOCK2;
          BLOCK2:
              next_state = CALC;
          CALC:
              if ((next_pe_state == ZERO) || (next_H_offset == max_H_offset) || (next_V_offset == max_V_offset))
                  next_state = DONE;
              else
                  next_state = BLOCK1;
          DONE:
              next_state = WAIT;
      endcase
  end

endmodule

