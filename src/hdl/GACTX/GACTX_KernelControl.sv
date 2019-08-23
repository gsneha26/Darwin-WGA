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

module GACTX_KernelControl #(
  parameter integer C_M_AXI_ADDR_WIDTH  = 64,
  parameter integer C_M_AXI_DATA_WIDTH  = 32,
  parameter integer C_XFER_SIZE_WIDTH   = C_M_AXI_ADDR_WIDTH,
  parameter integer C_AXIS_TDATA_WIDTH = 512,
  parameter integer C_ADDER_BIT_WIDTH  = 32,
  parameter integer NUM_AXI = 2
)
(
    input wire                             aclk,
    input wire                             areset,
    input wire                       	   ap_start,
    output wire                            ap_done,

    input wire  [NUM_AXI-1:0]              s_axis_tvalid,
    output wire [NUM_AXI-1:0]              s_axis_tready,
    input wire  [C_AXIS_TDATA_WIDTH-1:0]   s_axis_tdata[NUM_AXI-1:0],
    input wire  [C_AXIS_TDATA_WIDTH/8-1:0] s_axis_tkeep,
    input wire  [NUM_AXI-1:0]              s_axis_tlast,

    output wire [NUM_AXI-1:0]              m_axis_tvalid,
    input  wire [NUM_AXI-1:0]              m_axis_tready,
    output wire [C_AXIS_TDATA_WIDTH-1:0]   m_axis_tdata[NUM_AXI-1:0],
    output wire [C_AXIS_TDATA_WIDTH/8-1:0] m_axis_tkeep,
    output wire [NUM_AXI-1:0]              m_axis_tlast,

    output wire [NUM_AXI-1:0] 			   read_start,
    input wire  [NUM_AXI-1:0] 			   read_done,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]   read_addr_offset[NUM_AXI-1:0],
    output wire [C_XFER_SIZE_WIDTH-1:0]    read_byte_length[NUM_AXI-1:0],

    output wire [NUM_AXI-1:0] 			   write_start,
    input wire  [NUM_AXI-1:0] 			   write_done,
    output wire [C_M_AXI_ADDR_WIDTH-1:0]   write_addr_offset[NUM_AXI-1:0],
    output wire [C_XFER_SIZE_WIDTH-1:0]    write_byte_length[NUM_AXI-1:0],

    input  wire [32-1:0]                   sub_AA,
    input  wire [32-1:0]                   sub_AC,
    input  wire [32-1:0]                   sub_AG,
    input  wire [32-1:0]                   sub_AT,
    input  wire [32-1:0]                   sub_CC,
    input  wire [32-1:0]                   sub_CG,
    input  wire [32-1:0]                   sub_CT,
    input  wire [32-1:0]                   sub_GG,
    input  wire [32-1:0]                   sub_GT,
    input  wire [32-1:0]                   sub_TT,
    input  wire [32-1:0]                   sub_N,
    input  wire [32-1:0]                   gap_open,
    input  wire [32-1:0]                   gap_extend,
    input  wire [32-1:0]                   y_drop,
    input  wire [32-1:0]                   align_fields,
    input  wire [32-1:0]                   ref_len,
    input  wire [32-1:0]                   query_len,
    input  wire [64-1:0]                   ref_offset,
    input  wire [64-1:0]                   query_offset,

    input  wire [64-1:0]                   ref_seq,
    input  wire [64-1:0]                   query_seq,
    input  wire [64-1:0]                   tile_output,
    input  wire [64-1:0]                   tb_output      

);

localparam integer BLOCK_WIDTH = 3;
localparam integer BRAM_WIDTH_CHAR = (2 ** BLOCK_WIDTH);
localparam integer BRAM_WIDTH = 8*BRAM_WIDTH_CHAR;
localparam integer NUM_BRAM_LOOPS = C_AXIS_TDATA_WIDTH/BRAM_WIDTH;
localparam [C_ADDER_BIT_WIDTH-1:0] MASK = 63;
localparam integer BYTE_WIDTH = 8;
localparam integer DATA_WIDTH_BYTE = C_AXIS_TDATA_WIDTH/BYTE_WIDTH;
localparam integer PE_WIDTH = 21;
localparam integer NUM_PE = 32;
localparam integer MAX_TILE_SIZE = 2048;
localparam integer WORD_4 = 128; 
localparam integer LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE); 
localparam integer DIR_BRAM_ADDR_WIDTH = 8;
localparam integer NUM_DIR_BLOCK = 256;
localparam integer NUM_DIR_BLOCK_2 = 2*NUM_DIR_BLOCK;
localparam integer MASK_DIR = C_AXIS_TDATA_WIDTH/NUM_DIR_BLOCK_2 - 1;
localparam integer SHIFT_LEN = 6;
/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////
logic   [C_XFER_SIZE_WIDTH-1:0]  	 read_byte_length_logic[NUM_AXI-1:0];
logic   [64-1:0]  	        	 	 read_addr_offset_reg[NUM_AXI-1:0]; 
logic   [NUM_AXI-1:0]	           	 read_start_reg;


logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_ref;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_ref_out;
logic               				 ref_fifo_rd_en;
logic               				 ref_fifo_wr_en;
logic               				 ref_fifo_empty;
logic               				 ref_fifo_full;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_query;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_query_out;
logic               				 query_fifo_rd_en;
logic               				 query_fifo_wr_en;
logic               				 query_fifo_empty;
logic               				 query_fifo_full;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data1;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data2;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_reg;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_left;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_right;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 prev_data_ref;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 prev_data_query;
logic   [SHIFT_LEN-1:0]              left_shift_num;
logic   [SHIFT_LEN-1:0]              right_shift_num;

logic   [13*PE_WIDTH-1:0]            in_params;
logic                           	 start_GACT;
logic                                clear_done;
logic                                set_params;
logic                                done_GACT;
logic   [C_AXIS_TDATA_WIDTH-1:0]     tile_output_data;
logic   [C_AXIS_TDATA_WIDTH-1:0]     dir_output_data;

logic   [8*(2 ** BLOCK_WIDTH)-1:0]	 ref_in;
logic   [32-1:0]			         ref_wr_addr;
logic   [32-1:0]	            	 ref_len_reg;
logic                   	    	 ref_wr_en;

logic   [8*(2 ** BLOCK_WIDTH)-1:0]   query_in;
logic   [32-1:0]			         query_wr_addr;
logic   [32-1:0]	            	 query_len_reg;
logic 	                         	 query_wr_en;

logic   [3:0]                        iter_ref;
logic   [3:0]                        iter_query;
logic   [31:0]                       iter_dir;
logic   [32-1:0]	            	 total_char;
logic   [32-1:0]	            	 query_off;
logic   [32-1:0]	            	 ref_off;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_out[NUM_AXI-1:0];
logic   [NUM_AXI-1:0]	         	 m_axis_tvalid_reg = {NUM_AXI{1'b0}};
logic   [C_XFER_SIZE_WIDTH-1:0]  	 write_byte_length_logic[NUM_AXI-1:0];
logic   [64-1:0]  	        	 	 write_addr_offset_reg[NUM_AXI-1:0]; 
logic   [NUM_AXI-1:0]		       	 write_start_reg = {NUM_AXI{1'b0}};

logic                                ref_done;
logic                                query_done;
logic   [32-1:0]    dir_out_count;
logic   [NUM_DIR_BLOCK_2-1:0]        dir_out;
logic                                dir_out_valid;

logic rst;

typedef enum logic[3:0] {IDLE_REF_SEQ, BLOCK_REF0, SEND_REF_SEQ_OFFSET, BLOCK_REF1, READ_REF_SEQ, BLOCK3, DONE_REF_SEQ} state_ref;
state_ref state_ref_seq;

typedef enum logic[3:0] {IDLE_QUERY_SEQ, BLOCK_QUERY0, SEND_QUERY_SEQ_OFFSET, BLOCK_QUERY1, READ_QUERY_SEQ, BLOCK4, DONE_QUERY_SEQ} state_query;
state_query state_query_seq;

typedef enum logic[4:0] {IDLE0, WAIT0, READ_REF, SEND_REF_BLOCK, IDLE1, READ_QUERY, SEND_QUERY_BLOCK, DONE0, DONE1, CREATE_REF, CREATE_QUERY, STORE_REF1, STORE_REF2, STORE_QUERY1, STORE_QUERY2, REF_BLOCK1, QUERY_BLOCK1, REF_BLOCK2, QUERY_BLOCK2, CREATE_REF1, CREATE_REF2, CREATE_QUERY1, CREATE_QUERY2} state_bram_fill;
state_bram_fill state_ref_fill;

typedef enum logic[3:0] {IDLE_OUT, CREATE_OUT, BLOCK_OUT1, START_OUT, BLOCK_OUT, SEND_OUTPUT_ADDR, SEND_OUTPUT, DONE_OUT, BLOCK_OUTPUT, WAIT_OUTPUT, SEND_OUTPUT_DONE} state_output;
state_output state_out;

typedef enum logic[3:0] {IDLE_DIR, CREATE_DIR, BLOCK_DIR1, START_DIR, BLOCK_DIR, SEND_DIR_ADDR, SEND_DIR, DONE_DIR, WAIT_DIR, SEND_DIR_DONE} state_output_dir;
state_output_dir state_out_dir;
/////////////////////////////////////////////////////////////////////////////
// Compute Logic
/////////////////////////////////////////////////////////////////////////////

assign rst = areset | ap_start;

integer inn;

function [C_AXIS_TDATA_WIDTH-1:0] right_shift(input [C_AXIS_TDATA_WIDTH-1:0] inp, input [SHIFT_LEN-1:0] shift_amt);
    logic  [C_AXIS_TDATA_WIDTH-1:0] outp;

    for(inn = 0; inn < 64; inn = inn+1) begin
        if(inn == shift_amt) begin
            outp = (inp >> (BYTE_WIDTH*inn));
        end
    end

    return outp;
endfunction

function [C_AXIS_TDATA_WIDTH-1:0] left_shift(input [C_AXIS_TDATA_WIDTH-1:0] inp, input [SHIFT_LEN-1:0] shift_amt);
    logic  [C_AXIS_TDATA_WIDTH-1:0] outp;

    for(inn = 0; inn < 64; inn = inn+1) begin
        if(inn == shift_amt) begin
            outp = (inp << (BYTE_WIDTH*inn));
        end
    end

    return outp;
endfunction

FIFO#(
    .DATA_WIDTH(C_AXIS_TDATA_WIDTH),
    .ADDR_WIDTH(6)
) af_ref(
    .clk(aclk), 
    .rst(rst),
    .in(data_ref), 
    .out(data_ref_out),                            
    .empty(ref_fifo_empty), 
    .full(ref_fifo_full),
    .wr_en(ref_fifo_wr_en),
    .rd_en(ref_fifo_rd_en)
);

FIFO#(
    .DATA_WIDTH(C_AXIS_TDATA_WIDTH),
    .ADDR_WIDTH(6)
) af_query(
    .clk(aclk), 
    .rst(rst),
    .in(data_query), 
    .out(data_query_out),                            
    .empty(query_fifo_empty), 
    .full(query_fifo_full),
    .wr_en(query_fifo_wr_en),
    .rd_en(query_fifo_rd_en)
);


always @(posedge aclk) begin
    if(areset) begin
        iter_ref <= 4'd0;
        iter_query <= 4'd0;
        total_char <= 32'd0;
        ref_fifo_rd_en <= 0;
        query_fifo_rd_en <= 0;
        data1 <= {C_AXIS_TDATA_WIDTH{1'b0}};
        data2 <= {C_AXIS_TDATA_WIDTH{1'b0}};
        data_reg <= {C_AXIS_TDATA_WIDTH{1'b0}};
    end
    else begin
        case(state_ref_fill)
            IDLE0: begin
                data1 <= {C_AXIS_TDATA_WIDTH{1'b0}};
                data2 <= {C_M_AXI_DATA_WIDTH{1'b0}};
                data_reg <= {C_M_AXI_DATA_WIDTH{1'b0}};
                iter_ref <= 4'd0;
                iter_query <= 4'd0;
                total_char <= 32'd0;
                if(ref_done && query_done) begin
                    ref_fifo_rd_en <= 1;
                    query_fifo_rd_en <= 0;

                    ref_len_reg <= ref_len;
                    query_len_reg <= query_len;

                    ref_wr_addr <= 32'd0;
                    query_wr_addr <= 32'd0;
                    ref_wr_en <= 0;
                    query_wr_en <= 0;

                    start_GACT <= 0;
                    right_shift_num <= (ref_off & MASK);
                end
                else begin
                    ref_fifo_rd_en <= 0;
                    query_fifo_rd_en <= 0;
                end
            end

            REF_BLOCK1: begin
                ref_fifo_rd_en <= 0;
                set_params <= 1;
                left_shift_num <= DATA_WIDTH_BYTE - right_shift_num;
            end

            STORE_REF1: begin
                set_params <= 0;
                data1 <= data_ref_out;
            end

            CREATE_REF1: begin
                if(ref_fifo_empty == 0) begin
                    ref_fifo_rd_en <= 1;
                end
            end

            READ_REF: begin
                ref_wr_en <= 0;
                iter_ref <= 4'd0;
                data1 <= data2;
                if(ref_fifo_empty == 0) begin
                    ref_fifo_rd_en <= 1;
                end
            end

            REF_BLOCK2: begin
                ref_fifo_rd_en <= 0;
            end

            STORE_REF2: begin
                ref_fifo_rd_en <= 0;
                data2 <= data_ref_out;
            end

            CREATE_REF2: begin
                if(right_shift_num == 7'd0) begin
                    data_left <= {C_AXIS_TDATA_WIDTH{1'b0}};
                    data_right <= data1;
                end
                else begin
                    data_left <= left_shift(data2, left_shift_num);
                    data_right <= right_shift(data1, right_shift_num);
                end
            end

            CREATE_REF: begin
                data_reg <= data_right + data_left;
            end

            SEND_REF_BLOCK: begin
                iter_ref <= iter_ref + 4'd1;
                data_reg <= data_reg >> BRAM_WIDTH;
                ref_in <= data_reg[BRAM_WIDTH-1:0];
                ref_wr_en <= 1;
                total_char <= total_char + BRAM_WIDTH_CHAR;
                ref_wr_addr <= ref_wr_addr + 32'd1;
            end

            IDLE1: begin
                data1 <= {C_AXIS_TDATA_WIDTH{1'b0}};
                data2 <= {C_M_AXI_DATA_WIDTH{1'b0}};
                iter_ref <= 4'd0;
                iter_query <= 4'd0;
                ref_wr_addr <= 32'd0;
                query_wr_addr <= 32'd0;
                ref_wr_en <= 0;
                query_wr_en <= 0;
                total_char <= 32'd0; 
                query_fifo_rd_en <= 1;
                right_shift_num <= (query_off & MASK);
            end

            QUERY_BLOCK1: begin
                query_fifo_rd_en <= 0;
                left_shift_num <= DATA_WIDTH_BYTE - right_shift_num;
            end

            STORE_QUERY1: begin
                data1 <= data_query_out;
            end

            CREATE_QUERY1: begin
                if(query_fifo_empty == 0) begin
                    query_fifo_rd_en <= 1;
                end
            end

            READ_QUERY: begin
                iter_query <= 4'd0;
                query_wr_en <= 0;
                data1 <= data2;
                if(query_fifo_empty == 0) begin
                    query_fifo_rd_en <= 1;
                end
            end

            QUERY_BLOCK2: begin
                query_fifo_rd_en <= 0;
            end

            STORE_QUERY2: begin
                query_fifo_rd_en <= 0;
                data2 <= data_query_out;
            end

            CREATE_QUERY2: begin
                if(right_shift_num == 7'd0) begin
                    data_left <= {C_AXIS_TDATA_WIDTH{1'b0}};
                    data_right <= data1;
                end
                else begin
                    data_left <= left_shift(data2, left_shift_num);
                    data_right <= right_shift(data1, right_shift_num);
                end
            end

            CREATE_QUERY: begin
                data_reg <= data_right + data_left;
            end

            SEND_QUERY_BLOCK: begin
                iter_query <= iter_query + 4'd1;
                data_reg <= data_reg >> BRAM_WIDTH;
                query_in <= data_reg[BRAM_WIDTH-1:0]; 
                query_wr_en <= 1;
                total_char <= total_char + BRAM_WIDTH_CHAR;
                query_wr_addr <= query_wr_addr + 32'd1;
            end

            DONE0: begin
                start_GACT <= 1;
                ref_fifo_rd_en <= 0;
                query_fifo_rd_en <= 0;
            end

            DONE1: begin
                total_char <= 32'd0; 
                iter_ref <= 4'd0;
                iter_query <= 4'd0;
                ref_wr_addr <= 32'd0;
                query_wr_addr <= 32'd0;
                ref_wr_en <= 0;
                query_wr_en <= 0;
                start_GACT <= 0;
                ref_fifo_rd_en <= 0;
                query_fifo_rd_en <= 0;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_ref_fill <= IDLE0;
    end
    else begin
        case(state_ref_fill)
            IDLE0: begin
                if(ref_done && query_done) begin 
                    state_ref_fill <= REF_BLOCK1; 
                end
            end

            REF_BLOCK1: begin
                state_ref_fill <= STORE_REF1;
            end

            STORE_REF1: begin
                state_ref_fill <= CREATE_REF1;
            end

            CREATE_REF1: begin
                if(ref_fifo_empty) begin
                    state_ref_fill <= CREATE_REF2;
                end
                else begin
                    state_ref_fill <= REF_BLOCK2;
                end
            end

            READ_REF: begin
                if(total_char >=  ref_len) begin
                    state_ref_fill <= IDLE1;
                end
                else if(ref_fifo_empty) begin
                    state_ref_fill <= CREATE_REF2;
                end
                else begin
                    state_ref_fill <= REF_BLOCK2; 
                end
            end

            REF_BLOCK2: begin
                state_ref_fill <= STORE_REF2;
            end

            STORE_REF2: begin
                state_ref_fill <= CREATE_REF2;
            end

            CREATE_REF2: begin
                state_ref_fill <= CREATE_REF;
            end

            CREATE_REF: begin
                state_ref_fill <= SEND_REF_BLOCK;
            end

            SEND_REF_BLOCK: begin
                if(iter_ref == NUM_BRAM_LOOPS-1) begin
                    state_ref_fill <= READ_REF;
                end
                else if(total_char >=  ref_len) begin
                    state_ref_fill <= IDLE1;
                end
            end

            IDLE1: begin
                state_ref_fill <= QUERY_BLOCK1; 
            end

            QUERY_BLOCK1: begin
                state_ref_fill <= STORE_QUERY1;
            end

            STORE_QUERY1: begin
                state_ref_fill <= CREATE_QUERY1;
            end

            CREATE_QUERY1: begin
                if(query_fifo_empty) begin
                    state_ref_fill <= CREATE_QUERY2;
                end
                else begin
                    state_ref_fill <= QUERY_BLOCK2;
                end
            end

            READ_QUERY: begin
                if(total_char >= query_len) begin
                    state_ref_fill <= DONE0;
                end
                else if(query_fifo_empty) begin
                    state_ref_fill <= CREATE_QUERY2;
                end
                else begin
                    state_ref_fill <= QUERY_BLOCK2;
                end
            end

            QUERY_BLOCK2: begin
                state_ref_fill <= STORE_QUERY2;
            end

            STORE_QUERY2: begin
                state_ref_fill <= CREATE_QUERY2;
            end

            CREATE_QUERY2: begin
                state_ref_fill <= CREATE_QUERY;
            end

            CREATE_QUERY: begin
                state_ref_fill <= SEND_QUERY_BLOCK;
            end

            SEND_QUERY_BLOCK: begin
                if(iter_query == NUM_BRAM_LOOPS-1) begin
                    state_ref_fill <= READ_QUERY;
                end
                else if(total_char >= query_len) begin
                    state_ref_fill <= DONE0;
                end
            end

            DONE0: begin
                state_ref_fill <= DONE1;
            end

            DONE1: begin
                state_ref_fill <= IDLE0;
            end
        endcase
    end
end

assign in_params = {sub_AA[PE_WIDTH-1:0],
    		sub_AC[PE_WIDTH-1:0],
    		sub_AG[PE_WIDTH-1:0],
    		sub_AT[PE_WIDTH-1:0],
    		sub_CC[PE_WIDTH-1:0],
    		sub_CG[PE_WIDTH-1:0],
    		sub_CT[PE_WIDTH-1:0],
    		sub_GG[PE_WIDTH-1:0],
    		sub_GT[PE_WIDTH-1:0],
    		sub_TT[PE_WIDTH-1:0],
    		sub_N[PE_WIDTH-1:0],
    		gap_open[PE_WIDTH-1:0],
    		gap_extend[PE_WIDTH-1:0]};


GACTX_ArrayWrapper #(
    .PE_WIDTH(PE_WIDTH),
    .NUM_PE(NUM_PE),
    .MAX_TILE_SIZE(MAX_TILE_SIZE),
    .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE),
    .BLOCK_WIDTH(BLOCK_WIDTH),
    .DIR_BRAM_ADDR_WIDTH(DIR_BRAM_ADDR_WIDTH),
    .NUM_DIR_BLOCK(NUM_DIR_BLOCK) 
)gactx(
    .clk                  ( aclk                   ),
    .rst                  ( ap_start               ),
    .ref_in               ( ref_in                 ),
    .query_in             ( query_in               ),
    .ref_wr_en            ( ref_wr_en              ),
    .query_wr_en          ( query_wr_en            ),
    .ref_len              ( ref_len_reg            ),
    .query_len            ( query_len_reg          ),
    .ref_off              ( ref_off                ),
    .query_off            ( query_off              ),
    .ref_addr             ( ref_wr_addr            ),
    .query_addr           ( query_wr_addr          ),
    .start 	              ( start_GACT     	       ),
    .done_GACT	          ( done_GACT      	       ),
    .ready  	          ( GACT_ready     	       ),
    .tile_output          ( tile_output_data       ),
    .dir_out_count        ( dir_out_count          ),
    .dir_out              ( dir_out                ),
    .dir_out_valid        ( dir_out_valid          ),
    .clear_done	          ( clear_done     	       ),
    .set_params	          ( set_params	           ),
    .in_params            ( in_params              ),
    .y_drop               ( y_drop                 ),
    .align_fields         ( align_fields           )
);


always @(posedge aclk) begin
    if(areset) begin
        read_start_reg[0] <= 0; 
        read_byte_length_logic[0] <= 0;
        read_addr_offset_reg[0] <= 0;
        ref_fifo_wr_en <= 0;
    end
    else begin
        case(state_ref_seq)
            IDLE_REF_SEQ: begin
                read_start_reg[0] <= 0; 
                read_byte_length_logic[0] <= 0;
                read_addr_offset_reg[0] <= 0;
                ref_fifo_wr_en <= 0;
                ref_off <= ref_offset[31:0];
            end

            BLOCK_REF0: begin
                read_start_reg[0] <= 1;
                read_byte_length_logic[0] <= ref_len + (ref_off & MASK);
                read_addr_offset_reg[0] <= ref_seq + ref_off;
            end

            SEND_REF_SEQ_OFFSET: begin
                read_start_reg[0] <= 0;
                read_byte_length_logic[0] <= 0;
            end

            BLOCK_REF1: begin
                if(s_axis_tvalid[0]) begin
                    prev_data_ref <= s_axis_tdata[0];
                end
            end

            READ_REF_SEQ: begin
                if(s_axis_tvalid[0]) begin
                    prev_data_ref <= s_axis_tdata[0];
                    ref_fifo_wr_en <= 1;
                    data_ref <= prev_data_ref;
                end
                else begin
                    ref_fifo_wr_en <= 0;
                end
            end

            BLOCK3: begin
                ref_fifo_wr_en <= 1;
                data_ref <= prev_data_ref;
            end

            DONE_REF_SEQ: begin
                read_start_reg[0] <= 0; 
                read_byte_length_logic[0] <= 0;
                read_addr_offset_reg[0] <= 0;
                ref_fifo_wr_en <= 0;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_ref_seq <= IDLE_REF_SEQ;
    end
    else begin
        case(state_ref_seq)
            IDLE_REF_SEQ: begin
                if(ap_start) begin
                    state_ref_seq <= BLOCK_REF0;
                end
            end

            BLOCK_REF0: begin
                state_ref_seq <= SEND_REF_SEQ_OFFSET;
            end

            SEND_REF_SEQ_OFFSET: begin
                state_ref_seq <= BLOCK_REF1;
            end

            BLOCK_REF1: begin
                if(s_axis_tvalid[0]) begin
                    if(s_axis_tlast[0]) begin
                        state_ref_seq <= BLOCK3;
                    end
                    else begin
                        state_ref_seq <= READ_REF_SEQ;
                    end
                end
            end

            READ_REF_SEQ: begin
                if(s_axis_tvalid[0] && s_axis_tlast[0]) begin
                    state_ref_seq <= BLOCK3;
                end
            end

            BLOCK3: begin
                state_ref_seq <= DONE_REF_SEQ;
            end

            DONE_REF_SEQ: begin
                if(ref_done && query_done) begin
                    state_ref_seq <= IDLE_REF_SEQ;
                end
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        read_start_reg[1] <= 0; 
        read_byte_length_logic[1] <= 0;
        read_addr_offset_reg[1] <= 0;
        query_fifo_wr_en <= 0;
    end
    else begin
        case(state_query_seq)
            IDLE_QUERY_SEQ: begin
                read_start_reg[1] <= 0; 
                read_byte_length_logic[1] <= 0;
                read_addr_offset_reg[1] <= 0;
                query_fifo_wr_en <= 0;
                query_off <= query_offset[31:0];
            end

            BLOCK_QUERY0: begin
                read_start_reg[1] <= 1;
                read_byte_length_logic[1] <= query_len + (query_off & MASK);
                read_addr_offset_reg[1] <= query_seq + query_off;
            end

            SEND_QUERY_SEQ_OFFSET: begin
                read_start_reg[1] <= 0;
            end

            BLOCK_QUERY1: begin
                if(s_axis_tvalid[1]) begin
                    prev_data_query <= s_axis_tdata[1];
                end
            end

            READ_QUERY_SEQ: begin
                if(s_axis_tvalid[1]) begin
                    query_fifo_wr_en <= 1;
                    prev_data_query <= s_axis_tdata[1];
                    data_query <= prev_data_query;
                end
                else begin
                    query_fifo_wr_en <= 0;
                end
            end

            BLOCK4: begin
                query_fifo_wr_en <= 1;
                data_query <= prev_data_query;
            end

            DONE_QUERY_SEQ: begin
                read_start_reg[1] <= 0; 
                read_byte_length_logic[1] <= 0;
                read_addr_offset_reg[1] <= 0;
                query_fifo_wr_en <= 0;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_query_seq <= IDLE_QUERY_SEQ;
    end
    else begin
        case(state_query_seq)
            IDLE_QUERY_SEQ: begin
                if(ap_start) begin
                    state_query_seq <= BLOCK_QUERY0;
                end
            end

            BLOCK_QUERY0: begin
                state_query_seq <= SEND_QUERY_SEQ_OFFSET;
            end

            SEND_QUERY_SEQ_OFFSET: begin
                state_query_seq <= BLOCK_QUERY1;
            end

            BLOCK_QUERY1: begin
                if(s_axis_tvalid[1]) begin
                    if(s_axis_tlast[1]) begin
                        state_query_seq <= BLOCK4;
                    end
                    else begin
                        state_query_seq <= READ_QUERY_SEQ;
                    end
                end
            end

            READ_QUERY_SEQ: begin
                if(s_axis_tvalid[1] && s_axis_tlast[1]) begin
                    state_query_seq <= BLOCK4;
                end
            end

            BLOCK4: begin
                state_query_seq <= DONE_QUERY_SEQ;
            end

            DONE_QUERY_SEQ: begin
                if(ref_done && query_done) begin
                    state_query_seq <= IDLE_QUERY_SEQ;
                end
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        write_start_reg[0] <= 0; 
        m_axis_tvalid_reg[0] <= 0;
        write_byte_length_logic[0] <= 0;
        data_out[0] <= 512'd0;
    end
    else begin
        case(state_out)
            IDLE_OUT: begin
                write_start_reg[0] <= 0; 
                m_axis_tvalid_reg[0] <= 0;
                write_byte_length_logic[0] <= 0;
                data_out[0] <= 512'd0;
            end

            BLOCK_OUTPUT: begin
                write_start_reg[0] <= 1; 
                write_byte_length_logic[0] <= 32'd64;
                write_addr_offset_reg[0] <= tile_output;
            end

            SEND_OUTPUT_ADDR: begin
                write_start_reg[0] <= 0; 
                write_byte_length_logic[0] <= 32'd0;
                if(done_GACT) begin
                    data_out[0] <= tile_output_data;
                end
            end

            SEND_OUTPUT: begin
                m_axis_tvalid_reg[0] <= 1;
            end

            SEND_OUTPUT_DONE: begin
                m_axis_tvalid_reg[0] <= 0;
            end

            DONE_OUT: begin
                write_start_reg[0] <= 0; 
                m_axis_tvalid_reg[0] <= 0;
                write_byte_length_logic[0] <= 0;
            end

        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_out <= IDLE_OUT;
    end
    else begin
        case(state_out)
            IDLE_OUT: begin
                if(ap_start) begin
                    state_out <= BLOCK_OUTPUT;
                end
            end

            BLOCK_OUTPUT: begin
                state_out <= SEND_OUTPUT_ADDR;
            end

            SEND_OUTPUT_ADDR: begin
                if(done_GACT) begin
                    state_out <= SEND_OUTPUT;
                end
            end

            SEND_OUTPUT: begin
                state_out <= SEND_OUTPUT_DONE;
            end

            SEND_OUTPUT_DONE: begin
                if(write_done[0] == 1) begin
                    state_out <= DONE_OUT;
                end
            end

            DONE_OUT: begin
                state_out <= IDLE_OUT;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        write_start_reg[1] <= 0; 
        m_axis_tvalid_reg[1] <= 0;
        write_byte_length_logic[1] <= 0;
        data_out[1] <= 512'd0;
        iter_dir <= 32'd0;
        dir_output_data <= 512'd0;
    end
    else begin
        case(state_out_dir)
            IDLE_DIR: begin
                write_start_reg[1] <= 0; 
                m_axis_tvalid_reg[1] <= 0;
                write_byte_length_logic[1] <= 0;
                data_out[1] <= 512'd0;
                iter_dir <= 32'd0;
                dir_output_data <= 512'd0;
            end

            BLOCK_DIR: begin
                write_start_reg[1] <= 1; 
                write_byte_length_logic[1] <= (dir_out_count << 6);
                write_addr_offset_reg[1] <= tb_output;
            end

            SEND_DIR: begin
                write_start_reg[1] <= 0; 
                write_byte_length_logic[1] <= 32'd0;

                if(dir_out_valid) begin
                    iter_dir <= iter_dir + 32'd1;
                    m_axis_tvalid_reg[1] <= 1;
                    data_out[1] <= dir_out;
                end
                else begin
                    m_axis_tvalid_reg[1] <= 0;
                end
            end

            SEND_DIR_DONE: begin
                m_axis_tvalid_reg[1] <= 0;
            end

            DONE_DIR: begin
                write_start_reg[1] <= 0; 
                m_axis_tvalid_reg[1] <= 0;
                write_byte_length_logic[1] <= 0;
            end

        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_out_dir <= IDLE_DIR;
    end
    else begin
        case(state_out_dir)
            IDLE_DIR: begin
                if(done_GACT) begin
                    if(dir_out_count == 32'd0) begin
                        state_out_dir <= DONE_DIR;
                    end
                    else begin
                        state_out_dir <= BLOCK_DIR;
                    end
                end
            end

            BLOCK_DIR: begin
                state_out_dir <= SEND_DIR;
            end

            SEND_DIR: begin
                if(iter_dir == dir_out_count) begin
                    state_out_dir <= SEND_DIR_DONE;
                end
            end

            SEND_DIR_DONE: begin
                if(write_done[1] == 1) begin
                    state_out_dir <= DONE_DIR;
                end
            end

            DONE_DIR: begin
                state_out_dir <= IDLE_DIR;
            end
        endcase
    end
end

assign ref_done   = (state_ref_seq == DONE_REF_SEQ);
assign query_done = (state_query_seq == DONE_QUERY_SEQ);

assign read_start        = read_start_reg;
assign read_byte_length  = read_byte_length_logic;
assign read_addr_offset  = read_addr_offset_reg;

assign m_axis_tdata  = data_out;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign s_axis_tready = m_axis_tready;

assign ap_done = (state_out_dir == DONE_DIR);
assign clear_done = (state_out_dir == DONE_DIR);

assign write_start       = write_start_reg;
assign write_byte_length = write_byte_length_logic;
assign write_addr_offset = write_addr_offset_reg;

endmodule

`default_nettype wire
