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

module GACTX_ArrayWrapper #(
    parameter PE_WIDTH = 25,
    parameter NUM_PE = 64,
    parameter MAX_TILE_SIZE = 1024,
	parameter LOG_MAX_TILE_SIZE = 10,
	parameter BLOCK_WIDTH = 3,
    parameter DIR_BRAM_ADDR_WIDTH = 8,
    parameter NUM_DIR_BLOCK = 64
)
(
    input               		   clk,
    input               		   rst,
    input wire              	   start,
    input wire 				       set_params,
    input wire                     clear_done,

    input wire [13*PE_WIDTH-1:0]   in_params,
    input wire [32-1:0]            y_drop,
    input wire [32-1:0]            align_fields,

    input wire [64-1:0]    		   ref_in,
    input wire [32-1:0]    		   ref_addr,
    input wire [32-1:0]    		   ref_len,
    input wire [32-1:0]    		   ref_off,
    input wire     	   	     	   ref_wr_en,

    input wire [64-1:0]    		   query_in,
    input wire [32-1:0]    		   query_addr,
    input wire [32-1:0]    		   query_len,
    input wire [32-1:0]    		   query_off,
    input wire     	   	     	   query_wr_en,

    output wire [512-1:0]          tile_output,
    output wire 			       ready,
    output wire 			       done_GACT,

    output wire [32-1:0] dir_out_count,
    output wire [2*NUM_DIR_BLOCK-1:0] dir_out,
    output wire dir_out_valid
);

    wire [PE_WIDTH-1:0]               score;
    wire [LOG_MAX_TILE_SIZE-1:0]      ref_max_pos;
    wire [LOG_MAX_TILE_SIZE-1:0]      query_max_pos;
    reg  [32-1:0]                     tile_score;
    reg  [32-1:0]                     tile_ref_max_pos;
    reg  [32-1:0]                     tile_query_max_pos;

    reg  [3:0] state;

    localparam WAIT = 0, SEND_RESULT = 1, BLOCK1 = 2, READ_DIR = 3, SEND_DIR = 4, CREATE_RESULT = 5; 
    wire done;
    reg done_reg;

    reg [DIR_BRAM_ADDR_WIDTH-1:0] dir_rd_addr;
    wire [2*NUM_DIR_BLOCK-1:0] dir_data_out;
    wire [DIR_BRAM_ADDR_WIDTH-1:0] dir_total_count;

    reg [32-1:0] dir_out_count_reg;
    reg [2*NUM_DIR_BLOCK-1:0] dir_out_reg;
    reg dir_out_valid_reg;
    
    reg [64-1:0] ref_in0;
    reg [64-1:0] ref_in_last;
    reg [64-1:0] query_in0;
    reg [64-1:0] query_in_last;


    GACTX_Array #(
        .PE_WIDTH(PE_WIDTH),
        .BLOCK_WIDTH(BLOCK_WIDTH),
        .MAX_TILE_SIZE(MAX_TILE_SIZE),
        .NUM_PE(NUM_PE),
        .NUM_DIR_BLOCK(NUM_DIR_BLOCK),
        .DIR_BRAM_ADDR_WIDTH(DIR_BRAM_ADDR_WIDTH)
    ) dut (
        .clk             (clk),
        .rst             (rst),
        .align_fields    (align_fields[7:0]),
        .clear_done      (clear_done),

        .in_params       (in_params),
        .y_in            (y_drop[PE_WIDTH-1:0]),

        .query_addr_in   (query_addr[LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0]),
        .query_in        (query_in),
        .query_len       (query_len[LOG_MAX_TILE_SIZE-1:0]),
        .query_wr_en     (query_wr_en),
        .ref_addr_in     (ref_addr[LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0]),
        .ref_in          (ref_in),
        .ref_len         (ref_len[LOG_MAX_TILE_SIZE-1:0]),
        .ref_wr_en       (ref_wr_en),
        .set_params      (set_params),
        .start           (start),
        .done            (done),
        .ready           (ready),

        .query_max_pos   (query_max_pos),
        .ref_max_pos     (ref_max_pos),
        .tile_score      (score),

        .dir_rd_addr     (dir_rd_addr),
        .dir_total_count (dir_total_count),
        .dir_data_out    (dir_data_out)
    );
    
    always@(posedge clk) begin
        if(rst) begin
            state <= WAIT;
        end
        else begin
            case(state)
                WAIT: begin
                    if(start) begin
                        state <= CREATE_RESULT;
                    end
                end

                CREATE_RESULT: begin
                    if(done) begin
                        state <= SEND_RESULT;
                    end
                end

                SEND_RESULT: begin
                    if (dir_out_count_reg > 0) begin
                        state <= BLOCK1;
                    end
                    else begin
                        state <= WAIT;
                    end
                end

                BLOCK1: begin
                    state <= READ_DIR;
                end

                READ_DIR: begin
                    state <= SEND_DIR;
                end

                SEND_DIR: begin
                    if (dir_rd_addr == dir_out_count_reg-1) begin
                        state <= WAIT;
                    end                                                                       
                    else begin
                        state <= BLOCK1;
                    end
                end
            endcase
        end
    end

    always@(posedge clk) begin
        if(rst) begin
           tile_score <= 32'd0;
           tile_ref_max_pos <= 32'd0;
           tile_query_max_pos <= 32'd0;
           dir_out_count_reg <= 32'd0;
           done_reg <= 0;
        end
        else begin
            case(state)
                WAIT: begin
                    tile_score <= 32'd0;
                    tile_ref_max_pos <= 32'd0;
                    tile_query_max_pos <= 32'd0;
                    dir_out_count_reg <= 32'd0;
                    done_reg <= 0;

                    if(ref_wr_en == 1 && ref_addr == 32'd1) 
                        ref_in0 <= ref_in;

                    if(ref_wr_en == 1) 
                        ref_in_last <= ref_in;

                    if(query_wr_en == 1 && query_addr == 32'd1) 
                        query_in0 <= query_in;

                    if(query_wr_en == 1) 
                        query_in_last <= query_in;

                end

                CREATE_RESULT: begin
                    if(done) begin
                        tile_score <= score;
                        tile_ref_max_pos <= ref_max_pos;
                        tile_query_max_pos <= query_max_pos;
                        dir_out_count_reg <= dir_total_count;
                        done_reg <= 1;
                    end
                end

                SEND_RESULT: begin
                    dir_rd_addr <= 0;
                    done_reg <= 0;
                end

                BLOCK1: begin

                end

                READ_DIR: begin
                    dir_out_reg <= dir_data_out;
                    dir_out_valid_reg <= 1;
                end

                SEND_DIR: begin
                    dir_out_valid_reg <= 0;
                    dir_rd_addr <= dir_rd_addr + 1;
                end
            endcase
        end
    end

    assign tile_output = {query_in_last, query_in0, ref_in_last, ref_in0, query_off, ref_off, dir_out_count, query_len, ref_len, tile_query_max_pos, tile_ref_max_pos, tile_score};
    assign done_GACT = done_reg;

    assign dir_out_count = dir_out_count_reg;
    assign dir_out_valid = dir_out_valid_reg;
    assign dir_out = dir_out_reg;

endmodule

