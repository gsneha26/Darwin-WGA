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

module BSW_KernelControl #(
  parameter integer C_M_AXI_ADDR_WIDTH  = 64,
  parameter integer C_M_AXI_DATA_WIDTH  = 32,
  parameter integer C_XFER_SIZE_WIDTH   = C_M_AXI_ADDR_WIDTH,
  parameter integer C_AXIS_TDATA_WIDTH = 512,
  parameter integer C_ADDER_BIT_WIDTH  = 32,
  parameter integer NUM_AXI = 4
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
    input  wire [32-1:0]                   band_size,
    input  wire [32-1:0]                   batch_size,
    input  wire [32-1:0]                   batch_align_fields,

    input  wire [64-1:0]                   ref_seq,
    input  wire [64-1:0]                   query_seq,
    input  wire [64-1:0]                   batch_id,
    input  wire [64-1:0]                   batch_params,
    input  wire [64-1:0]                   batch_tile_output
);

localparam integer BLOCK_WIDTH = 3;
localparam integer BRAM_WIDTH_CHAR = (2 ** BLOCK_WIDTH);
localparam integer BRAM_WIDTH = 8*BRAM_WIDTH_CHAR;
localparam integer NUM_BRAM_LOOPS = C_AXIS_TDATA_WIDTH/BRAM_WIDTH;
localparam [C_ADDER_BIT_WIDTH-1:0] MASK = 63;
localparam integer BYTE_WIDTH = 8;
localparam integer DATA_WIDTH_BYTE = C_AXIS_TDATA_WIDTH/BYTE_WIDTH;
localparam integer NUM_TILES_PER_BATCH = 4;
localparam integer NUM_TILES_PER_BATCH_4 = NUM_TILES_PER_BATCH*4;
localparam integer NUM_BANDED_ARRAYS = 7;
localparam integer PE_WIDTH = 16;
localparam integer NUM_PE = 32;
localparam integer MAX_TILE_SIZE = 512;
localparam integer WORD_4 = 128; 
localparam integer FIFO_ADDR_WIDTH = 4; 
localparam integer LOG_MAX_TILE_SIZE = $clog2(MAX_TILE_SIZE); 

/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////
logic                                ap_done_reg = 1'b0;

logic   [C_XFER_SIZE_WIDTH-1:0]  	 read_byte_length_params[NUM_AXI-1:0];
logic   [64-1:0]  	        	 	 read_addr_offset_params[NUM_AXI-1:0]; 
logic   [NUM_AXI-1:0]              	 read_start_params;
logic                                start_params;

logic   [128-1:0] 	                 data_batch_id[NUM_TILES_PER_BATCH_4-1:0];
logic   [128-1:0] 	                 data_batch_params[NUM_TILES_PER_BATCH_4-1:0];

logic   [32-1:0]	            	 axi_batch_id[NUM_AXI-1:0];
logic   [32-1:0]	                 axi_ref_len[NUM_AXI-1:0];
logic   [32-1:0]	            	 axi_ref_off[NUM_AXI-1:0];
logic   [32-1:0]	                 axi_query_len[NUM_AXI-1:0];
logic   [32-1:0]	            	 axi_query_off[NUM_AXI-1:0];
logic   [32-1:0]	            	 tile_no;
logic   [32-1:0]	            	 tile_iter;
logic   [32-1:0]	            	 tile_iter_params[NUM_AXI-1:0];
logic   [32-1:0]	            	 tile_count;
logic   [32-1:0]	            	 tile_params_count;
logic   [32-1:0]	            	 available_axi;
logic   [32-1:0]	            	 available_axi_params;
logic   [32-1:0]	            	 available_axi_data;

logic   [C_XFER_SIZE_WIDTH-1:0]  	 read_byte_length_logic[NUM_AXI-1:0];
logic   [64-1:0]  	        	 	 read_addr_offset_reg[NUM_AXI-1:0]; 
logic   [NUM_AXI-1:0]	           	 read_start_reg = {NUM_AXI{1'b0}};

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 prev_data[NUM_AXI-1:0];
logic   [6:0]                        left_shift_num[NUM_AXI-1:0];
logic   [6:0]                        right_shift_num[NUM_AXI-1:0];

logic   [NUM_AXI-1:0]	           	 axi_ready;
logic   [NUM_AXI-1:0]	           	 axi_ready_params;
logic   [NUM_AXI-1:0]	           	 axi_req_ready;
logic   [NUM_AXI-1:0]	           	 axi_done;
logic   [NUM_AXI-1:0]	           	 axi_sent;
logic   [NUM_AXI-1:0]	           	 axi_fill;
logic   [NUM_AXI-1:0]	           	 axi_seq_start = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]	           	 axi_idle_params = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]	           	 axi_bram_start = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]  	           	 params_ready;
logic   [NUM_AXI-1:0]  	           	 params_complete;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_ref[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_ref_out[NUM_AXI-1:0];
logic   [NUM_AXI-1:0]				 ref_fifo_rd_en = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]				 ref_fifo_wr_en = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]				 ref_fifo_empty;
logic   [NUM_AXI-1:0]				 ref_fifo_full;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_query[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_query_out[NUM_AXI-1:0];
logic   [NUM_AXI-1:0]				 query_fifo_rd_en = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]				 query_fifo_wr_en = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]				 query_fifo_empty;
logic   [NUM_AXI-1:0]				 query_fifo_full;
logic   [NUM_AXI-1:0]				 fifo_rst = {NUM_AXI{1'b0}};
logic   [NUM_AXI-1:0]				 fifo_reset;

logic   [32-1:0]	            	 axi_array_no[NUM_AXI-1:0];
logic   [32-1:0]	            	 available_array;
logic   [32-1:0]	            	 available_array_output;

logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data1[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data2[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_reg[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_right[NUM_AXI-1:0];
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_left[NUM_AXI-1:0];

logic   [13*PE_WIDTH-1:0]            in_params;
logic   [NUM_BANDED_ARRAYS-1:0]	     start_GACT = {NUM_BANDED_ARRAYS{1'b0}};
logic   [NUM_BANDED_ARRAYS-1:0]      clear_done;
logic   [NUM_BANDED_ARRAYS-1:0]      set_params;
logic   [NUM_BANDED_ARRAYS-1:0]      array_rst;

logic   [8*(2 ** BLOCK_WIDTH)-1:0]   ref_in[NUM_BANDED_ARRAYS-1:0];
logic   [32-1:0]			         ref_wr_addr[NUM_BANDED_ARRAYS-1:0];
logic   [LOG_MAX_TILE_SIZE-1:0]	     ref_len[NUM_BANDED_ARRAYS-1:0];
logic 	[NUM_BANDED_ARRAYS-1:0]    	 ref_wr_en;

logic   [8*(2 ** BLOCK_WIDTH)-1:0]   query_in[NUM_BANDED_ARRAYS-1:0];
logic   [32-1:0]			         query_wr_addr[NUM_BANDED_ARRAYS-1:0];
logic   [LOG_MAX_TILE_SIZE-1:0]	     query_len[NUM_BANDED_ARRAYS-1:0];
logic 	[NUM_BANDED_ARRAYS-1:0]    	 query_wr_en;

logic   [32-1:0]	            	 tile_id[NUM_BANDED_ARRAYS-1:0];
logic   [32-1:0]	            	 axi_id[NUM_BANDED_ARRAYS-1:0];
logic   [32-1:0]	            	 num_tiles_gact_issue_reqs = 32'd0;

logic   [NUM_BANDED_ARRAYS-1:0]      done;
logic   [NUM_BANDED_ARRAYS-1:0]      GACT_ready;
logic   [NUM_BANDED_ARRAYS-1:0]      GACT_issued = {NUM_BANDED_ARRAYS{1'b0}};
logic   [NUM_BANDED_ARRAYS-1:0]      GACT_available;
logic   [C_AXIS_TDATA_WIDTH-1:0]     tile_output[NUM_BANDED_ARRAYS-1:0];

logic   [3:0]                        iter_ref[NUM_AXI-1:0];
logic   [3:0]                        iter_query[NUM_AXI-1:0];
logic   [32-1:0]	            	 total_char[NUM_AXI-1:0];

logic   [32-1:0]	            	 num_tiles_done = 32'd0;
logic   [32-1:0]	            	 num_inner_tiles_done = 32'd0;
logic   [32-1:0]	            	 num_in_tiles = 32'd0;
logic   [C_AXIS_TDATA_WIDTH-1:0] 	 data_out[NUM_AXI-1:0];
logic   [NUM_AXI-1:0]	         	 m_axis_tvalid_reg = {NUM_AXI{1'b0}};
logic   [C_XFER_SIZE_WIDTH-1:0]  	 write_byte_length_logic[NUM_AXI-1:0];
logic   [64-1:0]  	        	 	 write_addr_offset_reg[NUM_AXI-1:0]; 
logic   [NUM_AXI-1:0]		       	 write_start_reg = {NUM_AXI{1'b0}};

logic rst;

typedef enum logic[3:0] {IDLE_PARAMS, WAIT_PARAMS, BLOCK, SEND_BATCH_ID_ADDR, READ_BATCH_ID, BLOCK1, SEND_BATCH_PARAMS_ADDR, READ_BATCH_PARAMS, DONE_PARAMS} state_params;
state_params state_read_params [NUM_AXI-1:0];
typedef enum logic[2:0] {IDLE_REQ, START_REQ, ISSUE_REQ, BLOCK_REQ, BLOCK_REQ1, DONE_REQ} state_request;
state_request state_issue_reqs;
typedef enum logic[3:0] {IDLE_SEQ, WAIT_SEQ, BLOCK2, SEND_REF_SEQ_OFFSET, BLOCK_REF1, READ_REF_SEQ, BLOCK3, SEND_QUERY_SEQ_OFFSET, BLOCK_QUERY1, READ_QUERY_SEQ, BLOCK4, DONE_SEQ} state_seq;
state_seq state_read_seq [NUM_AXI-1:0];
typedef enum logic[2:0] {IDLE_GACT_REQ, ISSUE_GACT_REQ, BLOCK_GACT_REQ1, BLOCK_GACT_REQ, DONE_GACT_REQ} state_gact_request;
state_gact_request state_issue_gact_reqs;
typedef enum logic[4:0] {IDLE0, WAIT0, READ_REF, SEND_REF_BLOCK, IDLE1, READ_QUERY, SEND_QUERY_BLOCK, DONE0, DONE1, CREATE_REF, CREATE_QUERY, STORE_REF1, STORE_REF2, STORE_QUERY1, STORE_QUERY2, REF_BLOCK1, QUERY_BLOCK1, REF_BLOCK2, QUERY_BLOCK2, CREATE_REF1, CREATE_REF2, CREATE_QUERY1, CREATE_QUERY2} state_bram_fill;
state_bram_fill state_ref_fill [NUM_AXI-1:0];
typedef enum logic[3:0] {IDLE_OUT, CREATE_OUT, BLOCK_OUT1, START_OUT, BLOCK_OUT, SEND_OUTPUT_ADDR, SEND_OUTPUT, DONE_OUT, BLOCK_OUTPUT, WAIT_OUTPUT, SEND_OUTPUT_DONE} state_output;
state_output state_out;
/////////////////////////////////////////////////////////////////////////////
// Compute Logic
/////////////////////////////////////////////////////////////////////////////

assign rst = areset | ap_start;

integer inn;

function [32-1:0] next_available_axi(input [NUM_AXI-1:0] ready_sig);
    logic  [32-1:0] outp;

    for(inn = NUM_AXI-1; inn >= 0; inn=inn-1) begin
        if(ready_sig[inn] == 1) begin
            outp = inn;
        end
    end

    return outp;
endfunction

function [32-1:0] next_available_array(input [NUM_BANDED_ARRAYS-1:0] ready_sig);
    logic  [32-1:0] outp;

    for(inn = NUM_BANDED_ARRAYS-1; inn >= 0; inn=inn-1) begin
        if(ready_sig[inn] == 1) begin
            outp = inn;
        end
    end

    return outp;
endfunction

function [C_AXIS_TDATA_WIDTH-1:0] right_shift(input [C_AXIS_TDATA_WIDTH-1:0] inp, input [6:0] shift_amt);
    logic  [C_AXIS_TDATA_WIDTH-1:0] outp;

    for(inn = 0; inn < 64; inn = inn+1) begin
        if(inn == shift_amt) begin
            outp = (inp >> (BYTE_WIDTH*inn));
        end
    end

    return outp;
endfunction

function [C_AXIS_TDATA_WIDTH-1:0] left_shift(input [C_AXIS_TDATA_WIDTH-1:0] inp, input [6:0] shift_amt);
    logic  [C_AXIS_TDATA_WIDTH-1:0] outp;

    for(inn = 0; inn < 64; inn = inn+1) begin
        if(inn == shift_amt) begin
            outp = (inp << (BYTE_WIDTH*inn));
        end
    end

    return outp;
endfunction

genvar ft;
generate
for (ft = 0; ft < NUM_AXI; ft = ft+1)
begin: fifo_gen 
FIFO#(
    .DATA_WIDTH(C_AXIS_TDATA_WIDTH),
    .ADDR_WIDTH(4)
) af_ref(
    .clk(aclk), 
    .rst(fifo_reset[ft]),
    .in(data_ref[ft]), 
    .out(data_ref_out[ft]),                            
    .empty(ref_fifo_empty[ft]), 
    .full(ref_fifo_full[ft]),
    .wr_en(ref_fifo_wr_en[ft]),
    .rd_en(ref_fifo_rd_en[ft])
);

FIFO#(
    .DATA_WIDTH(C_AXIS_TDATA_WIDTH),
    .ADDR_WIDTH(4)
) af_query(
    .clk(aclk), 
    .rst(fifo_reset[ft]),
    .in(data_query[ft]), 
    .out(data_query_out[ft]),                            
    .empty(query_fifo_empty[ft]), 
    .full(query_fifo_full[ft]),
    .wr_en(query_fifo_wr_en[ft]),
    .rd_en(query_fifo_rd_en[ft])
);
end
endgenerate

always @(posedge aclk) begin
    if(areset) begin
        axi_bram_start <= {NUM_AXI{1'b0}};
        num_tiles_gact_issue_reqs <= 32'd0;
    end
    else begin
        case(state_issue_gact_reqs)
            IDLE_GACT_REQ: begin
                num_tiles_gact_issue_reqs <= 32'd0;
                axi_bram_start <= {NUM_AXI{1'b0}};
                if(axi_fill > {NUM_AXI{1'b0}} && GACT_available > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    available_array <= next_available_array(GACT_available);
                    available_axi_data <= next_available_axi(axi_fill);
                end
            end

            ISSUE_GACT_REQ: begin
                axi_array_no[available_axi_data] <= available_array;
                axi_bram_start[available_axi_data] <= 1;
                num_tiles_gact_issue_reqs <= num_tiles_gact_issue_reqs + 32'd1;
            end

            BLOCK_GACT_REQ1: begin
                axi_bram_start[available_axi_data] <= 0;
            end

            BLOCK_GACT_REQ: begin
                if(axi_fill > {NUM_AXI{1'b0}} && GACT_available > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    available_array <= next_available_array(GACT_available);
                    available_axi_data <= next_available_axi(axi_fill);
                end
            end

            DONE_GACT_REQ: begin
                axi_bram_start <= {NUM_AXI{1'b0}};
                num_tiles_gact_issue_reqs <= 32'd0;
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_issue_gact_reqs <= IDLE_GACT_REQ;
    end
    else begin
        case(state_issue_gact_reqs)
            IDLE_GACT_REQ: begin
                if(axi_fill > {NUM_AXI{1'b0}} && GACT_available > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    state_issue_gact_reqs <= ISSUE_GACT_REQ; 
                end
            end

            ISSUE_GACT_REQ: begin
                state_issue_gact_reqs <= BLOCK_GACT_REQ1;
            end

            BLOCK_GACT_REQ1: begin
                state_issue_gact_reqs <= BLOCK_GACT_REQ;
            end

            BLOCK_GACT_REQ: begin
                if(num_tiles_gact_issue_reqs == batch_size) begin
                    state_issue_gact_reqs <= DONE_GACT_REQ;
                end
                else if(axi_fill > {NUM_AXI{1'b0}} && GACT_available > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    state_issue_gact_reqs <= ISSUE_GACT_REQ;
                end
            end

            DONE_GACT_REQ: begin
                state_issue_gact_reqs <= IDLE_GACT_REQ;
            end
        endcase
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            iter_ref[j] <= 4'd0;
            iter_query[j] <= 4'd0;
            total_char[j] <= 32'd0;
            ref_fifo_rd_en[j] <= 0;
            query_fifo_rd_en[j] <= 0;
            fifo_rst[j] <= 0;
            data1[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
            data2[j] <= {C_AXIS_TDATA_WIDTH{1'b0}};
            data_reg[j] <= {C_AXIS_TDATA_WIDTH{1'b0}};
        end
        else begin
            case(state_ref_fill[j])
                IDLE0: begin
                    iter_ref[j] <= 4'd0;
                    iter_query[j] <= 4'd0;
                    total_char[j] <= 32'd0;
                    ref_fifo_rd_en[j] <= 0;
                    query_fifo_rd_en[j] <= 0;
                    fifo_rst[j] <= 0;
                    data1[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    data2[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    data_reg[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                end

                WAIT0: begin
                    data1[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    data2[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    data_reg[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    iter_ref[j] <= 4'd0;
                    iter_query[j] <= 4'd0;
                    total_char[j] <= 32'd0;
                    if(axi_bram_start[j] == 1) begin
                        ref_fifo_rd_en[j] <= 1;
                        query_fifo_rd_en[j] <= 0;

                        tile_id[axi_array_no[j]] <= axi_batch_id[j];
                        axi_id[axi_array_no[j]] <= j;
                        ref_len[axi_array_no[j]] <= axi_ref_len[j][LOG_MAX_TILE_SIZE-1:0];
                        query_len[axi_array_no[j]] <= axi_query_len[j][LOG_MAX_TILE_SIZE-1:0];

                        ref_wr_addr[axi_array_no[j]] <= 32'd0;
                        query_wr_addr[axi_array_no[j]] <= 32'd0;
                        ref_wr_en[axi_array_no[j]] <= 0;
                        query_wr_en[axi_array_no[j]] <= 0;

                        start_GACT[axi_array_no[j]] <= 0;
                        GACT_issued[axi_array_no[j]] <= 1;
                        array_rst[axi_array_no[j]] <= 1;
                        right_shift_num[j] <= (axi_ref_off[j] & MASK);
                    end
                    else begin
                        ref_fifo_rd_en[j] <= 0;
                        query_fifo_rd_en[j] <= 0;
                    end
                end

                REF_BLOCK1: begin
                    ref_fifo_rd_en[j] <= 0;
                    array_rst[axi_array_no[j]] <= 0;
                    set_params[axi_array_no[j]] <= 1;
                    left_shift_num[j] <= DATA_WIDTH_BYTE - right_shift_num[j];
                end

                STORE_REF1: begin
                    set_params[axi_array_no[j]] <= 0;
                    data1[j] <= data_ref_out[j];
                end

                CREATE_REF1: begin
                    if(ref_fifo_empty[j] == 0) begin
                        ref_fifo_rd_en[j] <= 1;
                    end
                end

                READ_REF: begin
                    iter_ref[j] <= 4'd0;
                    ref_wr_en[axi_array_no[j]] <= 0;
                    data1[j] <= data2[j];
                    if(ref_fifo_empty[j] == 0) begin
                        ref_fifo_rd_en[j] <= 1;
                    end
                end

                REF_BLOCK2: begin
                    ref_fifo_rd_en[j] <= 0;
                end

                STORE_REF2: begin
                    ref_fifo_rd_en[j] <= 0;
                    data2[j] <= data_ref_out[j];
                end

                CREATE_REF2: begin
                    if(right_shift_num[j] == 7'd0) begin
                        data_left[j] <= {C_AXIS_TDATA_WIDTH{1'b0}};
                        data_right[j] <= data1[j];
                    end
                    else begin
                        data_left[j] <= left_shift(data2[j], left_shift_num[j]);
                        data_right[j] <= right_shift(data1[j], right_shift_num[j]);
                    end
                end

                CREATE_REF: begin
                    data_reg[j] <= data_right[j] + data_left[j];
                end

                SEND_REF_BLOCK: begin
                    iter_ref[j] <= iter_ref[j] + 4'd1;
                    data_reg[j] <= data_reg[j] >> BRAM_WIDTH;
                    ref_in[axi_array_no[j]] <= data_reg[j][BRAM_WIDTH-1:0];
                    ref_wr_en[axi_array_no[j]] <= 1;
                    total_char[j] <= total_char[j] + BRAM_WIDTH_CHAR;
                    ref_wr_addr[axi_array_no[j]] <= ref_wr_addr[axi_array_no[j]] + 32'd1;
                end

                IDLE1: begin
                    data1[j] <= {C_AXIS_TDATA_WIDTH{1'b0}};
                    data2[j] <= {C_M_AXI_DATA_WIDTH{1'b0}};
                    iter_ref[j] <= 4'd0;
                    iter_query[j] <= 4'd0;
                    ref_wr_addr[axi_array_no[j]] <= 32'd0;
                    query_wr_addr[axi_array_no[j]] <= 32'd0;
                    ref_wr_en[axi_array_no[j]] <= 0;
                    query_wr_en[axi_array_no[j]] <= 0;
                    total_char[j] <= 32'd0; 
                    query_fifo_rd_en[j] <= 1;
                    right_shift_num[j] <= (axi_query_off[j] & MASK);
                end

                QUERY_BLOCK1: begin
                    query_fifo_rd_en[j] <= 0;
                    left_shift_num[j] <= DATA_WIDTH_BYTE - right_shift_num[j];
                end

                STORE_QUERY1: begin
                    data1[j] <= data_query_out[j];
                end

                CREATE_QUERY1: begin
                    if(query_fifo_empty[j] == 0) begin
                        query_fifo_rd_en[j] <= 1;
                    end
                end

                READ_QUERY: begin
                    iter_query[j] <= 4'd0;
                    query_wr_en[axi_array_no[j]] <= 0;
                    data1[j] <= data2[j];
                    if(query_fifo_empty[j] == 0) begin
                        query_fifo_rd_en[j] <= 1;
                    end
                end

                QUERY_BLOCK2: begin
                    query_fifo_rd_en[j] <= 0;
                end

                STORE_QUERY2: begin
                    query_fifo_rd_en[j] <= 0;
                    data2[j] <= data_query_out[j];
                end

                CREATE_QUERY2: begin
                    if(right_shift_num[j] == 7'd0) begin
                        data_left[j] <= {C_AXIS_TDATA_WIDTH{1'b0}};
                        data_right[j] <= data1[j];
                    end
                    else begin
                        data_left[j] <= left_shift(data2[j], left_shift_num[j]);
                        data_right[j] <= right_shift(data1[j], right_shift_num[j]);
                    end
                end
                 
                CREATE_QUERY: begin
                    data_reg[j] <= data_right[j] + data_left[j];
                end

                SEND_QUERY_BLOCK: begin
                    iter_query[j] <= iter_query[j] + 4'd1;
                    data_reg[j] <= data_reg[j] >> BRAM_WIDTH;
                    query_in[axi_array_no[j]] <= data_reg[j][BRAM_WIDTH-1:0]; 
                    query_wr_en[axi_array_no[j]] <= 1;
                    total_char[j] <= total_char[j] + BRAM_WIDTH_CHAR;
                    query_wr_addr[axi_array_no[j]] <= query_wr_addr[axi_array_no[j]] + 32'd1;
                end

                DONE0: begin
                    start_GACT[axi_array_no[j]] <= 1;
                    ref_fifo_rd_en[j] <= 0;
                    query_fifo_rd_en[j] <= 0;
                    fifo_rst[j] <= 1;
                end

                DONE1: begin
                    GACT_issued[axi_array_no[j]] <= 0;
                    total_char[j] <= 32'd0; 
                    iter_ref[j] <= 4'd0;
                    iter_query[j] <= 4'd0;
                    ref_wr_addr[axi_array_no[j]] <= 32'd0;
                    query_wr_addr[axi_array_no[j]] <= 32'd0;
                    ref_wr_en[axi_array_no[j]] <= 0;
                    query_wr_en[axi_array_no[j]] <= 0;
                    start_GACT[axi_array_no[j]] <= 0;
                    ref_fifo_rd_en[j] <= 0;
                    query_fifo_rd_en[j] <= 0;
                    fifo_rst[j] <= 0;
                end
            endcase
        end
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            state_ref_fill[j] <= IDLE0;
        end
        else begin
            case(state_ref_fill[j])
                IDLE0: begin
                    if(axi_done[j] == 1) begin
                        state_ref_fill[j] <= WAIT0; 
                    end
                end

                WAIT0: begin
                    if(axi_bram_start[j] == 1) begin
                        state_ref_fill[j] <= REF_BLOCK1; 
                    end
                end

                REF_BLOCK1: begin
                    state_ref_fill[j] <= STORE_REF1;
                end

                STORE_REF1: begin
                    state_ref_fill[j] <= CREATE_REF1;
                end

                CREATE_REF1: begin
                    if(ref_fifo_empty[j]) begin
                        state_ref_fill[j] <= CREATE_REF2;
                    end
                    else begin
                        state_ref_fill[j] <= REF_BLOCK2;
                    end
                end

                READ_REF: begin
                    if(total_char[j] >=  ref_len[axi_array_no[j]]) begin
                        state_ref_fill[j] <= IDLE1;
                    end
                    else if(ref_fifo_empty[j]) begin
                        state_ref_fill[j] <= CREATE_REF2;
                    end
                    else begin
                        state_ref_fill[j] <= REF_BLOCK2; 
                    end
                end

                REF_BLOCK2: begin
                    state_ref_fill[j] <= STORE_REF2;
                end

                STORE_REF2: begin
                    state_ref_fill[j] <= CREATE_REF2;
                end

                CREATE_REF2: begin
                    state_ref_fill[j] <= CREATE_REF;
                end

                CREATE_REF: begin
                    state_ref_fill[j] <= SEND_REF_BLOCK;
                end

                SEND_REF_BLOCK: begin
                    if(iter_ref[j] == NUM_BRAM_LOOPS-1) begin
                        state_ref_fill[j] <= READ_REF;
                    end
                    else if(total_char[j] >=  ref_len[axi_array_no[j]]) begin
                        state_ref_fill[j] <= IDLE1;
                    end
                end

                IDLE1: begin
                    state_ref_fill[j] <= QUERY_BLOCK1; 
                end

                QUERY_BLOCK1: begin
                    state_ref_fill[j] <= STORE_QUERY1;
                end

                STORE_QUERY1: begin
                    state_ref_fill[j] <= CREATE_QUERY1;
                end

                CREATE_QUERY1: begin
                    if(query_fifo_empty[j]) begin
                        state_ref_fill[j] <= CREATE_QUERY2;
                    end
                    else begin
                        state_ref_fill[j] <= QUERY_BLOCK2;
                    end
                end

                READ_QUERY: begin
                    if(total_char[j] >= query_len[axi_array_no[j]]) begin
                        state_ref_fill[j] <= DONE0;
                    end
                    else if(query_fifo_empty[j]) begin
                        state_ref_fill[j] <= CREATE_QUERY2;
                    end
                    else begin
                        state_ref_fill[j] <= QUERY_BLOCK2;
                    end
                end

                QUERY_BLOCK2: begin
                    state_ref_fill[j] <= STORE_QUERY2;
                end

                STORE_QUERY2: begin
                    state_ref_fill[j] <= CREATE_QUERY2;
                end

                CREATE_QUERY2: begin
                    state_ref_fill[j] <= CREATE_QUERY;
                end

                CREATE_QUERY: begin
                    state_ref_fill[j] <= SEND_QUERY_BLOCK;
                end

                SEND_QUERY_BLOCK: begin
                    if(iter_query[j] == NUM_BRAM_LOOPS-1) begin
                        state_ref_fill[j] <= READ_QUERY;
                    end
                    else if(total_char[j] >= query_len[axi_array_no[j]]) begin
                        state_ref_fill[j] <= DONE0;
                    end
                end

                DONE0: begin
                    state_ref_fill[j] <= DONE1;
                end

                DONE1: begin
                    state_ref_fill[j] <= IDLE0;
                end
            endcase
        end
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

genvar it;
generate
for (it = 0; it < NUM_BANDED_ARRAYS; it = it+1)
begin: array_gen 
BSW_Array #(
    .NUM_PE(NUM_PE),
    .PE_WIDTH(PE_WIDTH),
    .BLOCK_WIDTH(BLOCK_WIDTH),
    .MAX_TILE_SIZE(MAX_TILE_SIZE),
    .LOG_MAX_TILE_SIZE(LOG_MAX_TILE_SIZE)
)inst_array(
    .clk                  ( aclk                                                ),
    .rst                  ( array_rst[it] | areset                              ),
    .start 	              ( start_GACT[it]     	                                ),
    .ready  	          ( GACT_ready[it]     	                                ),
    .set_param	          ( set_params[it]	                                    ),
    .done	              ( done[it]      	                                    ),
    .clear_done	          ( clear_done[it]     	                                ),
    .in_params            ( in_params                                           ),
    .band_size            ( band_size[LOG_MAX_TILE_SIZE-1:0]                    ),
    .align_fields         ( batch_align_fields[7:0]                             ),
    .tile_id              ( tile_id[it]                                         ),
    .array_id             ( it                                                  ),
    .ref_wr_en            ( ref_wr_en[it]                                       ),
    .query_wr_en          ( query_wr_en[it]                                     ),
    .ref_addr             ( ref_wr_addr[it][LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0]  ),
    .query_addr           ( query_wr_addr[it][LOG_MAX_TILE_SIZE-BLOCK_WIDTH-1:0]),
    .ref_in               ( ref_in[it]                                          ),
    .query_in             ( query_in[it]                                        ),
    .ref_len              ( ref_len[it]                                         ),
    .query_len            ( query_len[it]                                       ),
    .tile_output          ( tile_output[it]                                     )
);
end
endgenerate

always @(posedge aclk) begin
    if(areset) begin
        tile_no <= 32'd0;
        tile_iter <= 32'd0;
        tile_count <= 32'd0;
        axi_seq_start <= {NUM_AXI{1'b0}};
        axi_idle_params <= {NUM_AXI{1'b0}};
    end
    else begin
        case(state_issue_reqs)
            IDLE_REQ: begin
                tile_no <= 32'd0;
                axi_seq_start <= {NUM_AXI{1'b0}};
                if(params_ready > {NUM_AXI{1'b0}}) begin
                    available_axi_params <= next_available_axi(params_ready);
                end
            end

            START_REQ: begin
                axi_idle_params[available_axi_params] <= 1'b1;
                if(axi_req_ready > {NUM_AXI{1'b0}}) begin
                    available_axi <= next_available_axi(axi_req_ready);
                end
            end

            ISSUE_REQ: begin
                axi_idle_params[available_axi_params] <= 1'b0;
                axi_seq_start[available_axi] <= 1;
                axi_batch_id[available_axi] <= data_batch_id[(available_axi_params << 2) +tile_no][32-1:0];
                axi_ref_off[available_axi] <= data_batch_params[(available_axi_params << 2) +tile_no][32-1:0];
                axi_ref_len[available_axi] <=  data_batch_params[(available_axi_params << 2) +tile_no][96-1:64];
                axi_query_off[available_axi] <=  data_batch_params[(available_axi_params << 2) +tile_no][64-1:32];
                axi_query_len[available_axi] <=  data_batch_params[(available_axi_params << 2) +tile_no][128-1:96];
                tile_no <= tile_no + 32'd1;
                tile_count <= tile_count + 32'd1;
            end

            BLOCK_REQ1: begin
                axi_seq_start[available_axi] <= 0;
            end

            BLOCK_REQ: begin
            end

            DONE_REQ: begin
                axi_seq_start <= {NUM_AXI{1'b0}};
                tile_no <= 32'd0;
                tile_count <= 32'd0;
                if(tile_iter < ((batch_size >> 4) - 1)) begin
                    tile_iter <= tile_iter + 32'd1;
                end
                else begin
                    tile_iter <= 32'd0;
                end
                axi_idle_params <= {NUM_AXI{1'b0}};
            end
        endcase
    end
end

always @(posedge aclk) begin
    if(areset) begin
        state_issue_reqs <= IDLE_REQ;
    end
    else begin
        case(state_issue_reqs)
            IDLE_REQ: begin
                if(params_ready > {NUM_AXI{1'b0}}) begin
                    state_issue_reqs <= START_REQ; 
                end
            end

            START_REQ: begin
                if(axi_req_ready > {NUM_AXI{1'b0}}) begin
                    state_issue_reqs <= ISSUE_REQ;
                end
            end

            ISSUE_REQ: begin
                state_issue_reqs <= BLOCK_REQ1;
            end

            BLOCK_REQ1: begin
                state_issue_reqs <= BLOCK_REQ;
            end

            BLOCK_REQ: begin
                if(tile_no == 4 && tile_count < 16) begin
                    state_issue_reqs <= IDLE_REQ;
                end
                else if(tile_count == 16) begin
                    state_issue_reqs <= DONE_REQ;
                end
                else begin
                    state_issue_reqs <= START_REQ;
                end
            end

            DONE_REQ: begin
                state_issue_reqs <= IDLE_REQ;
            end
        endcase
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            read_start_params[j] <= 0; 
            read_byte_length_params[j] <= 32'd0;
            read_addr_offset_params[j] <= 0;
            tile_iter_params[j] <= 32'd0;
        end
        else begin
            case(state_read_params[j])
                IDLE_PARAMS: begin
                    read_start_params[j] <= 0; 
                    read_byte_length_params[j] <= 32'd0;
                    read_addr_offset_params[j] <= 0;
                    if(ap_start) begin
                        tile_iter_params[j] <= 32'd0;
                    end
                end

                WAIT_PARAMS: begin
                    read_start_params[j] <= 0; 
                    read_byte_length_params[j] <= 32'd0;
                    read_addr_offset_params[j] <= 0;
                end

                BLOCK: begin
                    read_start_params[j] <= 1;
                    read_byte_length_params[j] <= 32'd64;
                    read_addr_offset_params[j] <= batch_id + (j << 6) + (tile_iter << 8);
                end

                SEND_BATCH_ID_ADDR: begin
                    read_start_params[j] <= 0;
                    read_byte_length_params[j] <= 32'd0;
                    read_addr_offset_params[j] <= 0;
                end

                READ_BATCH_ID: begin
                    if(s_axis_tvalid[j]) begin
                        data_batch_id[j << 2] <= s_axis_tdata[j][127:0];
                        data_batch_id[(j << 2) + 1] <= s_axis_tdata[j][255:128];
                        data_batch_id[(j << 2) + 2] <= s_axis_tdata[j][383:256];
                        data_batch_id[(j << 2) + 3] <= s_axis_tdata[j][511:384];
                    end
                end

                BLOCK1: begin
                    read_start_params[j] <= 1;
                    read_byte_length_params[j] <= 32'd64;
                    read_addr_offset_params[j] <= batch_params + (j << 6) + (tile_iter << 8);
                end

                SEND_BATCH_PARAMS_ADDR: begin
                    read_start_params[j] <= 0;
                    read_byte_length_params[j] <= 32'd0;
                    read_addr_offset_params[j] <= 0;
                end

                READ_BATCH_PARAMS: begin
                    if(s_axis_tvalid[j]) begin
                        data_batch_params[j << 2] <= s_axis_tdata[j][127:0];
                        data_batch_params[(j << 2) + 1] <= s_axis_tdata[j][255:128];
                        data_batch_params[(j << 2) + 2] <= s_axis_tdata[j][383:256];
                        data_batch_params[(j << 2) + 3] <= s_axis_tdata[j][511:384];
                    end
                end

                DONE_PARAMS: begin
                    read_start_params[j] <= 0; 
                    read_byte_length_params[j] <= 0;
                    read_addr_offset_params[j] <= 0;
                    if(axi_idle_params[j]) begin
                        tile_iter_params[j] <= tile_iter_params[j] + 32'd1;
                    end
                end
            endcase
        end
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            state_read_params[j] <= IDLE_PARAMS;
        end
        else begin
            case(state_read_params[j])
                IDLE_PARAMS: begin
                    if(start_params && ((tile_iter_params[j] << 4) < batch_size)) begin
                        state_read_params[j] <= WAIT_PARAMS; 
                    end
                    else if(ap_start) begin
                        state_read_params[j] <= BLOCK; 
                    end
                end

                WAIT_PARAMS: begin
                    if(axi_ready[j]) begin
                        state_read_params[j] <= BLOCK; 
                    end
                end

                BLOCK: begin
                    state_read_params[j] <= SEND_BATCH_ID_ADDR;
                end

                SEND_BATCH_ID_ADDR: begin
                    state_read_params[j] <= READ_BATCH_ID;
                end

                READ_BATCH_ID: begin
                    if(s_axis_tvalid[j] && s_axis_tlast[j]) begin
                        state_read_params[j] <= BLOCK1; 
                    end
                end

                BLOCK1: begin
                    state_read_params[j] <= SEND_BATCH_PARAMS_ADDR;
                end

                SEND_BATCH_PARAMS_ADDR: begin
                    state_read_params[j] <= READ_BATCH_PARAMS;
                end

                READ_BATCH_PARAMS: begin
                    if(s_axis_tvalid[j] && s_axis_tlast[j]) begin
                        state_read_params[j] <= DONE_PARAMS; 
                    end
                end

                DONE_PARAMS: begin
                    if(axi_idle_params[j]) begin
                        state_read_params[j] <= IDLE_PARAMS;
                    end
                end
            endcase
        end
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            read_start_reg[j] <= 0; 
            read_byte_length_logic[j] <= 0;
            read_addr_offset_reg[j] <= 0;
            query_fifo_wr_en[j] <= 0;
            ref_fifo_wr_en[j] <= 0;
        end
        else begin
            case(state_read_seq[j])
                IDLE_SEQ: begin
                    read_start_reg[j] <= 0; 
                    read_byte_length_logic[j] <= 0;
                    read_addr_offset_reg[j] <= 0;
                    query_fifo_wr_en[j] <= 0;
                    ref_fifo_wr_en[j] <= 0;
                end

                WAIT_SEQ: begin
                    read_start_reg[j] <= 0; 
                    read_byte_length_logic[j] <= 0;
                    read_addr_offset_reg[j] <= 0;
                    query_fifo_wr_en[j] <= 0;
                    ref_fifo_wr_en[j] <= 0;
                end

                BLOCK2: begin
                    read_start_reg[j] <= 1;
                    read_byte_length_logic[j] <= axi_ref_len[j] + (axi_ref_off[j] & MASK);
                    read_addr_offset_reg[j] <= ref_seq + axi_ref_off[j];
                end

                SEND_REF_SEQ_OFFSET: begin
                    read_start_reg[j] <= 0;
                    read_byte_length_logic[j] <= 32'd0;
                end

                BLOCK_REF1: begin
                    if(s_axis_tvalid[j]) begin
                        prev_data[j] <= s_axis_tdata[j];
                    end
                end

                READ_REF_SEQ: begin
                    if(s_axis_tvalid[j]) begin
                        prev_data[j] <= s_axis_tdata[j];
                        ref_fifo_wr_en[j] <= 1;
                        data_ref[j] <= prev_data[j];
                    end
                    else begin
                        ref_fifo_wr_en[j] <= 0;
                    end
                end

                BLOCK3: begin
                    ref_fifo_wr_en[j] <= 1;
                    data_ref[j] <= prev_data[j];

                    read_start_reg[j] <= 1;
                    read_byte_length_logic[j] <= axi_query_len[j] + (axi_query_off[j] & MASK);
                    read_addr_offset_reg[j] <= query_seq + axi_query_off[j];
                end

                SEND_QUERY_SEQ_OFFSET: begin
                    ref_fifo_wr_en[j] <= 0;
                    read_start_reg[j] <= 0;
                    read_byte_length_logic[j] <= 32'd0;
                end

                BLOCK_QUERY1: begin
                    if(s_axis_tvalid[j]) begin
                        prev_data[j] <= s_axis_tdata[j];
                    end
                end

                READ_QUERY_SEQ: begin
                    if(s_axis_tvalid[j]) begin
                        query_fifo_wr_en[j] <= 1;
                        prev_data[j] <= s_axis_tdata[j];
                        data_query[j] <= prev_data[j];
                    end
                    else begin
                        query_fifo_wr_en[j] <= 0;
                    end
                end

                BLOCK4: begin
                    query_fifo_wr_en[j] <= 1;
                    data_query[j] <= prev_data[j];
                end

                DONE_SEQ: begin
                    read_start_reg[j] <= 0; 
                    read_byte_length_logic[j] <= 0;
                    read_addr_offset_reg[j] <= 0;
                    query_fifo_wr_en[j] <= 0;
                    ref_fifo_wr_en[j] <= 0;
                end
            endcase
        end
    end
end

always @(posedge aclk) begin
    for(integer j = 0; j < NUM_AXI; j=j+1) begin
        if(areset) begin
            state_read_seq[j] <= WAIT_SEQ;
        end
        else begin
            case(state_read_seq[j])
                IDLE_SEQ: begin
                    if(axi_sent[j] | ap_start) begin
                        state_read_seq[j] <= WAIT_SEQ; 
                    end
                end

                WAIT_SEQ: begin
                    if(axi_seq_start[j]) begin
                        state_read_seq[j] <= BLOCK2; 
                    end
                end

                BLOCK2: begin
                    state_read_seq[j] <= SEND_REF_SEQ_OFFSET; 
                end

                SEND_REF_SEQ_OFFSET: begin
                    state_read_seq[j] <= BLOCK_REF1;
                end

                BLOCK_REF1: begin
                    if(s_axis_tvalid[j]) begin
                        if(s_axis_tlast[j]) begin
                            state_read_seq[j] <= BLOCK3;
                        end
                        else begin
                            state_read_seq[j] <= READ_REF_SEQ; 
                        end
                    end
                end

                READ_REF_SEQ: begin
                    if(s_axis_tvalid[j] && s_axis_tlast[j]) begin
                        state_read_seq[j] <= BLOCK3; 
                    end
                end

                BLOCK3: begin
                    state_read_seq[j] <= SEND_QUERY_SEQ_OFFSET; 
                end

                SEND_QUERY_SEQ_OFFSET: begin
                    state_read_seq[j] <= BLOCK_QUERY1;
                end

                BLOCK_QUERY1: begin
                    if(s_axis_tvalid[j]) begin
                        if(s_axis_tlast[j]) begin
                            state_read_seq[j] <= BLOCK4;
                        end
                        else begin
                            state_read_seq[j] <= READ_QUERY_SEQ; 
                        end
                    end
                end

                READ_QUERY_SEQ: begin
                    if(s_axis_tvalid[j] && s_axis_tlast[j]) begin
                        state_read_seq[j] <= BLOCK4; 
                    end
                end

                BLOCK4: begin
                    state_read_seq[j] <= DONE_SEQ; 
                end

                DONE_SEQ: begin
                    state_read_seq[j] <= IDLE_SEQ;
                end
            endcase
        end
    end
end

always @(posedge aclk) begin
    if(areset) begin
        num_tiles_done <= 32'd0;
        num_inner_tiles_done <= 32'd0;
        write_start_reg <= 4'b0000; 
        m_axis_tvalid_reg <= 4'b0000;
        write_byte_length_logic[0] <= 0;
        write_byte_length_logic[1] <= 0;
        write_byte_length_logic[2] <= 0;
        write_byte_length_logic[3] <= 0;
        data_out[0] <= 512'd0;
        data_out[1] <= 512'd0;
        data_out[2] <= 512'd0;
        data_out[3] <= 512'd0;
    end
    else begin
        case(state_out)
            IDLE_OUT: begin
                write_start_reg <= 4'b0000; 
                m_axis_tvalid_reg <= 4'b0000;
                write_byte_length_logic[0] <= 0;
                data_out[0] <= 512'd0;
                num_tiles_done <= 32'd0;
                num_inner_tiles_done <= 32'd0;
            end

            BLOCK_OUTPUT: begin
                write_start_reg <= 4'b0001; 
                write_byte_length_logic[0] <= batch_size << 6;
                write_addr_offset_reg[0] <= batch_tile_output;
            end

            SEND_OUTPUT_ADDR: begin
                write_start_reg <= 4'b0000; 
                write_byte_length_logic[0] <= 32'd0;
            end

            WAIT_OUTPUT: begin
                if(done > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    available_array_output <= next_available_array(done);
                end
            end

            CREATE_OUT: begin
                data_out[0] <= tile_output[available_array_output];
                clear_done[available_array_output] <= 1;          
                num_tiles_done <= num_tiles_done + 32'd1;
                num_inner_tiles_done <= num_inner_tiles_done + 32'd1;
            end

            BLOCK_OUT1: begin
                clear_done[available_array_output] <= 0;          
            end

            BLOCK_OUT: begin
                if(num_inner_tiles_done == 1) begin
                    num_inner_tiles_done <= 32'd0;
                end
            end

            SEND_OUTPUT: begin
                m_axis_tvalid_reg <= 4'b0001;
            end

            SEND_OUTPUT_DONE: begin
                m_axis_tvalid_reg <= 4'b0000;
            end

            DONE_OUT: begin
                num_tiles_done <= 32'd0;
                num_inner_tiles_done <= 32'd0;
                write_start_reg <= 4'b0000; 
                m_axis_tvalid_reg <= 4'b0000;
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
                state_out <= WAIT_OUTPUT;
            end

            WAIT_OUTPUT: begin
                if(done > {NUM_BANDED_ARRAYS{1'b0}}) begin
                    state_out <= CREATE_OUT; 
                end
            end

            CREATE_OUT: begin
                state_out <= BLOCK_OUT1; 
            end

            BLOCK_OUT1: begin
                state_out <= BLOCK_OUT; 
            end

            BLOCK_OUT: begin
                if(num_inner_tiles_done == 1) begin //NUM_TILES_PER_BATCH) begin
                    state_out <= SEND_OUTPUT; 
                end
                else begin
                    state_out <= WAIT_OUTPUT;
                end
            end

            SEND_OUTPUT: begin
                state_out <= SEND_OUTPUT_DONE;
            end

            SEND_OUTPUT_DONE: begin
                if(num_tiles_done < batch_size) begin
                    state_out <= WAIT_OUTPUT;
                end
                else begin
                    if(write_done[0] == 1) begin
                        state_out <= DONE_OUT;
                    end
                end
            end

            DONE_OUT: begin
                state_out <= IDLE_OUT;
            end
        endcase
    end
end

genvar j;
generate
for(j = 0; j < NUM_AXI; j=j+1) 
begin:ready_sigs
    assign axi_ready[j]     = (state_read_seq[j] == WAIT_SEQ);
    assign axi_fill[j]      = (state_ref_fill[j] == WAIT0);
    assign axi_sent[j]      = (state_ref_fill[j] == DONE1);
    assign axi_done[j]      = (state_read_seq[j] == DONE_SEQ);
    assign params_ready[j]  = (state_read_params[j] == DONE_PARAMS);
    assign axi_ready_params[j]  = (state_read_params[j] == IDLE_PARAMS | state_read_params[j] == DONE_PARAMS);
    assign fifo_reset[j] = fifo_rst[j] | rst;
end
endgenerate

assign start_params = (tile_count == 32'd16);
assign axi_req_ready = axi_ready & ref_fifo_empty & query_fifo_empty & axi_ready_params;

assign GACT_available = GACT_ready & ~GACT_issued;

generate
for(j = 0; j < NUM_AXI; j=j+1) 
begin:data_out_sigs
    assign read_start[j]        = (axi_ready[j]) ? read_start_params[j] :  read_start_reg[j];
    assign read_byte_length[j]  = (axi_ready[j]) ? read_byte_length_params[j] : read_byte_length_logic[j];
    assign read_addr_offset[j]  = (axi_ready[j]) ? read_addr_offset_params[j] : read_addr_offset_reg[j];
end
endgenerate

assign m_axis_tdata  = data_out;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign s_axis_tready = m_axis_tready;

assign ap_done = (state_out == DONE_OUT);

assign write_start       = write_start_reg;
assign write_byte_length = write_byte_length_logic;
assign write_addr_offset = write_addr_offset_reg;

endmodule

`default_nettype wire
