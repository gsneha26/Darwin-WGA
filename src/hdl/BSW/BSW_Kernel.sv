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

`default_nettype none
module BSW_Kernel #(
  parameter integer C_M_AXI_ADDR_WIDTH = 64 ,
  parameter integer C_M_AXI_DATA_WIDTH = 512
)
(
  // System Signals
  input  wire                              aclk            ,
  input  wire                              areset          ,
  // AXI4 master interface m00_axi
  output wire                              m00_axi_awvalid   ,
  input  wire                              m00_axi_awready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m00_axi_awaddr    ,
  output wire [8-1:0]                      m00_axi_awlen     ,
  output wire                              m00_axi_wvalid    ,
  input  wire                              m00_axi_wready    ,
  output wire [C_M_AXI_DATA_WIDTH-1:0]   m00_axi_wdata     ,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0] m00_axi_wstrb     ,
  output wire                              m00_axi_wlast     ,
  input  wire                              m00_axi_bvalid    ,
  output wire                              m00_axi_bready    ,
  output wire                              m00_axi_arvalid   ,
  input  wire                              m00_axi_arready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m00_axi_araddr    ,
  output wire [8-1:0]                      m00_axi_arlen     ,
  input  wire                              m00_axi_rvalid    ,
  output wire                              m00_axi_rready    ,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]   m00_axi_rdata     ,
  input  wire                              m00_axi_rlast     ,
  // AXI4 master interface m01_axi
  output wire                              m01_axi_awvalid   ,
  input  wire                              m01_axi_awready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m01_axi_awaddr    ,
  output wire [8-1:0]                      m01_axi_awlen     ,
  output wire                              m01_axi_wvalid    ,
  input  wire                              m01_axi_wready    ,
  output wire [C_M_AXI_DATA_WIDTH-1:0]   m01_axi_wdata     ,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0] m01_axi_wstrb     ,
  output wire                              m01_axi_wlast     ,
  input  wire                              m01_axi_bvalid    ,
  output wire                              m01_axi_bready    ,
  output wire                              m01_axi_arvalid   ,
  input  wire                              m01_axi_arready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m01_axi_araddr    ,
  output wire [8-1:0]                      m01_axi_arlen     ,
  input  wire                              m01_axi_rvalid    ,
  output wire                              m01_axi_rready    ,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]   m01_axi_rdata     ,
  input  wire                              m01_axi_rlast     ,
  // AXI4 master interface m02_axi
  output wire                              m02_axi_awvalid   ,
  input  wire                              m02_axi_awready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m02_axi_awaddr    ,
  output wire [8-1:0]                      m02_axi_awlen     ,
  output wire                              m02_axi_wvalid    ,
  input  wire                              m02_axi_wready    ,
  output wire [C_M_AXI_DATA_WIDTH-1:0]   m02_axi_wdata     ,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0] m02_axi_wstrb     ,
  output wire                              m02_axi_wlast     ,
  input  wire                              m02_axi_bvalid    ,
  output wire                              m02_axi_bready    ,
  output wire                              m02_axi_arvalid   ,
  input  wire                              m02_axi_arready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m02_axi_araddr    ,
  output wire [8-1:0]                      m02_axi_arlen     ,
  input  wire                              m02_axi_rvalid    ,
  output wire                              m02_axi_rready    ,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]   m02_axi_rdata     ,
  input  wire                              m02_axi_rlast     ,
  // AXI4 master interface m03_axi
  output wire                              m03_axi_awvalid   ,
  input  wire                              m03_axi_awready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m03_axi_awaddr    ,
  output wire [8-1:0]                      m03_axi_awlen     ,
  output wire                              m03_axi_wvalid    ,
  input  wire                              m03_axi_wready    ,
  output wire [C_M_AXI_DATA_WIDTH-1:0]   m03_axi_wdata     ,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0] m03_axi_wstrb     ,
  output wire                              m03_axi_wlast     ,
  input  wire                              m03_axi_bvalid    ,
  output wire                              m03_axi_bready    ,
  output wire                              m03_axi_arvalid   ,
  input  wire                              m03_axi_arready   ,
  output wire [C_M_AXI_ADDR_WIDTH-1:0]   m03_axi_araddr    ,
  output wire [8-1:0]                      m03_axi_arlen     ,
  input  wire                              m03_axi_rvalid    ,
  output wire                              m03_axi_rready    ,
  input  wire [C_M_AXI_DATA_WIDTH-1:0]   m03_axi_rdata     ,
  input  wire                              m03_axi_rlast     ,
  // SDx Control Signals
  input  wire                              ap_start          ,
  output wire                              ap_idle           ,
  output wire                              ap_done           ,
  input  wire [32-1:0]                     sub_AA            ,
  input  wire [32-1:0]                     sub_AC            ,
  input  wire [32-1:0]                     sub_AG            ,
  input  wire [32-1:0]                     sub_AT            ,
  input  wire [32-1:0]                     sub_CC            ,
  input  wire [32-1:0]                     sub_CG            ,
  input  wire [32-1:0]                     sub_CT            ,
  input  wire [32-1:0]                     sub_GG            ,
  input  wire [32-1:0]                     sub_GT            ,
  input  wire [32-1:0]                     sub_TT            ,
  input  wire [32-1:0]                     sub_N             ,
  input  wire [32-1:0]                     gap_open          ,
  input  wire [32-1:0]                     gap_extend        ,
  input  wire [32-1:0]                     band_size         ,
  input  wire [32-1:0]                     batch_size        ,
  input  wire [32-1:0]                     batch_align_fields,
  input  wire [64-1:0]                     ref_seq           ,
  input  wire [64-1:0]                     query_seq         ,
  input  wire [64-1:0]                     batch_id          ,
  input  wire [64-1:0]                     batch_params      ,
  input  wire [64-1:0]                     batch_tile_output 
);


timeunit 1ps;
timeprecision 1ps;

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////
localparam integer LP_DW_BYTES             = C_M_AXI_DATA_WIDTH/8;
localparam integer LP_AXI_BURST_LEN        = 4096/LP_DW_BYTES < 256 ? 4096/LP_DW_BYTES : 256;
localparam integer LP_LOG_BURST_LEN        = $clog2(LP_AXI_BURST_LEN);
localparam integer LP_BRAM_DEPTH           = 512;
localparam integer LP_RD_MAX_OUTSTANDING   = LP_BRAM_DEPTH / LP_AXI_BURST_LEN;
localparam integer LP_WR_MAX_OUTSTANDING   = 32;
localparam integer NUM_AXI                 = 4;
localparam integer C_XFER_SIZE_WIDTH       = 32;
localparam integer C_ADDER_BIT_WIDTH       = 32;

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////

// AXI read master stage
logic [3:0]                    read_done;
logic [3:0]                    rd_tvalid;
logic [3:0]                    rd_tready;
logic [3:0]                    rd_tlast;
logic [C_M_AXI_DATA_WIDTH-1:0] rd_tdata[3:0];
// Adder stage
logic [3:0]                    adder_tvalid;
logic [3:0]                    adder_tready;
logic [C_M_AXI_DATA_WIDTH-1:0] adder_tdata[3:0];

// AXI write master stage
logic [3:0]                    write_done;

logic [C_XFER_SIZE_WIDTH-1:0]  read_xfer_byte_length[3:0];
logic [C_XFER_SIZE_WIDTH-1:0]  write_xfer_byte_length[3:0];

logic [C_M_AXI_ADDR_WIDTH-1:0] read_addr_offset[3:0];
logic [C_M_AXI_ADDR_WIDTH-1:0] write_addr_offset[3:0];

logic [3:0] 				   read_start;
logic [3:0] 				   write_start;
logic rst;
///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
(* KEEP = "yes" *)
logic                                ap_start_r                     = 1'b0;
logic                                ap_idle_r                      = 1'b0;
logic                                ap_start_pulse                ;
logic                                ap_done_i                     ;
logic                                ap_done_r                      = 1'b0;

///////////////////////////////////////////////////////////////////////////////
// Begin RTL
///////////////////////////////////////////////////////////////////////////////

assign rst = areset | ap_start_pulse;

// create pulse when ap_start transitions to 1
always @(posedge aclk) begin
  begin
    ap_start_r <= ap_start;
  end
end

assign ap_start_pulse = ap_start & ~ap_start_r;

// ap_idle is asserted when done is asserted, it is de-asserted when ap_start_pulse
// is asserted
always @(posedge aclk) begin
  if (areset) begin
    ap_idle_r <= 1'b1;
  end
  else begin
    ap_idle_r <= ap_done ? 1'b1 :
      ap_start_pulse ? 1'b0 : ap_idle;
  end
end

assign ap_idle = ap_idle_r;

// Done logic
always @(posedge aclk) begin
  if (areset) begin
    ap_done_r <= '0;
  end
  else begin
    ap_done_r <= (ap_start_pulse | ap_done) ? '0 : ap_done_r | ap_done_i;
  end
end

assign ap_done = &ap_done_r;

// AXI4 Read Master, output format is an AXI4-Stream master, one stream per thread.
axi_read_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_RD_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi00_read_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( read_start[0]                ) ,
  .ctrl_done               ( read_done[0]               ) ,
  .ctrl_addr_offset        ( read_addr_offset[0]        ) ,
  .ctrl_xfer_size_in_bytes ( read_xfer_byte_length[0]   ) ,
  .m_axi_arvalid           ( m00_axi_arvalid           ) ,
  .m_axi_arready           ( m00_axi_arready           ) ,
  .m_axi_araddr            ( m00_axi_araddr            ) ,
  .m_axi_arlen             ( m00_axi_arlen             ) ,
  .m_axi_rvalid            ( m00_axi_rvalid            ) ,
  .m_axi_rready            ( m00_axi_rready            ) ,
  .m_axi_rdata             ( m00_axi_rdata             ) ,
  .m_axi_rlast             ( m00_axi_rlast             ) ,
  .m_axis_aclk             ( aclk              ) ,
  .m_axis_areset           ( areset              ) ,
  .m_axis_tvalid           ( rd_tvalid[0]               ) ,
  .m_axis_tready           ( rd_tready[0]               ) ,
  .m_axis_tlast            ( rd_tlast[0]                ) ,
  .m_axis_tdata            ( rd_tdata[0]                )
);

// AXI4 Read Master, output format is an AXI4-Stream master, one stream per thread.
axi_read_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_RD_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi01_read_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( read_start[1]                ) ,
  .ctrl_done               ( read_done[1]               ) ,
  .ctrl_addr_offset        ( read_addr_offset[1]        ) ,
  .ctrl_xfer_size_in_bytes ( read_xfer_byte_length[1]   ) ,
  .m_axi_arvalid           ( m01_axi_arvalid           ) ,
  .m_axi_arready           ( m01_axi_arready           ) ,
  .m_axi_araddr            ( m01_axi_araddr            ) ,
  .m_axi_arlen             ( m01_axi_arlen             ) ,
  .m_axi_rvalid            ( m01_axi_rvalid            ) ,
  .m_axi_rready            ( m01_axi_rready            ) ,
  .m_axi_rdata             ( m01_axi_rdata             ) ,
  .m_axi_rlast             ( m01_axi_rlast             ) ,
  .m_axis_aclk             ( aclk              ) ,
  .m_axis_areset           ( areset              ) ,
  .m_axis_tvalid           ( rd_tvalid[1]               ) ,
  .m_axis_tready           ( rd_tready[1]               ) ,
  .m_axis_tlast            ( rd_tlast[1]                ) ,
  .m_axis_tdata            ( rd_tdata[1]                )
);

// AXI4 Read Master, output format is an AXI4-Stream master, one stream per thread.
axi_read_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_RD_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi02_read_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( read_start[2]                ) ,
  .ctrl_done               ( read_done[2]               ) ,
  .ctrl_addr_offset        ( read_addr_offset[2]        ) ,
  .ctrl_xfer_size_in_bytes ( read_xfer_byte_length[2]   ) ,
  .m_axi_arvalid           ( m02_axi_arvalid           ) ,
  .m_axi_arready           ( m02_axi_arready           ) ,
  .m_axi_araddr            ( m02_axi_araddr            ) ,
  .m_axi_arlen             ( m02_axi_arlen             ) ,
  .m_axi_rvalid            ( m02_axi_rvalid            ) ,
  .m_axi_rready            ( m02_axi_rready            ) ,
  .m_axi_rdata             ( m02_axi_rdata             ) ,
  .m_axi_rlast             ( m02_axi_rlast             ) ,
  .m_axis_aclk             ( aclk              ) ,
  .m_axis_areset           ( areset              ) ,
  .m_axis_tvalid           ( rd_tvalid[2]               ) ,
  .m_axis_tready           ( rd_tready[2]               ) ,
  .m_axis_tlast            ( rd_tlast[2]                ) ,
  .m_axis_tdata            ( rd_tdata[2]                )
);

// AXI4 Read Master, output format is an AXI4-Stream master, one stream per thread.
axi_read_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_RD_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi03_read_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( read_start[3]                ) ,
  .ctrl_done               ( read_done[3]               ) ,
  .ctrl_addr_offset        ( read_addr_offset[3]        ) ,
  .ctrl_xfer_size_in_bytes ( read_xfer_byte_length[3]   ) ,
  .m_axi_arvalid           ( m03_axi_arvalid           ) ,
  .m_axi_arready           ( m03_axi_arready           ) ,
  .m_axi_araddr            ( m03_axi_araddr            ) ,
  .m_axi_arlen             ( m03_axi_arlen             ) ,
  .m_axi_rvalid            ( m03_axi_rvalid            ) ,
  .m_axi_rready            ( m03_axi_rready            ) ,
  .m_axi_rdata             ( m03_axi_rdata             ) ,
  .m_axi_rlast             ( m03_axi_rlast             ) ,
  .m_axis_aclk             ( aclk              ) ,
  .m_axis_areset           ( areset              ) ,
  .m_axis_tvalid           ( rd_tvalid[3]               ) ,
  .m_axis_tready           ( rd_tready[3]               ) ,
  .m_axis_tlast            ( rd_tlast[3]                ) ,
  .m_axis_tdata            ( rd_tdata[3]                )
);

BSW_KernelControl #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH  ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH  ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH   ) ,
  .C_AXIS_TDATA_WIDTH  ( C_M_AXI_DATA_WIDTH  ) ,
  .C_ADDER_BIT_WIDTH   ( C_ADDER_BIT_WIDTH   ) ,
  .NUM_AXI             ( NUM_AXI             )
)
inst_kernel_control  (
  .aclk                    ( aclk                     ) ,
  .areset                  ( areset                    ) ,
  .ap_start                ( ap_start_pulse                       ),
  .ap_done                 ( ap_done_i                        ),
  .read_addr_offset	       ( read_addr_offset 		        ),
  .read_byte_length	       ( read_xfer_byte_length  	    ),
  .read_start		       ( read_start			            ),
  .read_done		       ( read_done			            ),
  .write_addr_offset	   ( write_addr_offset		        ),
  .write_byte_length	   ( write_xfer_byte_length         ),
  .write_start		       ( write_start		            ),
  .write_done		       ( write_done		                ),
  .sub_AA                  ( sub_AA                         ),
  .sub_AC                  ( sub_AC                         ),
  .sub_AG                  ( sub_AG                         ),
  .sub_AT                  ( sub_AT                         ),
  .sub_CC                  ( sub_CC                         ),
  .sub_CG                  ( sub_CG                         ),
  .sub_CT                  ( sub_CT                         ),
  .sub_GG                  ( sub_GG                         ),
  .sub_GT                  ( sub_GT                         ),
  .sub_TT                  ( sub_TT                         ),
  .sub_N                   ( sub_N                          ),
  .gap_open                ( gap_open                       ),
  .gap_extend              ( gap_extend                     ),
  .band_size               ( band_size                      ),
  .batch_size              ( batch_size                     ),
  .batch_align_fields      ( batch_align_fields             ),
  .ref_seq                 ( ref_seq                        ),
  .query_seq               ( query_seq                      ),
  .batch_id                ( batch_id                       ),
  .batch_params            ( batch_params                   ),
  .batch_tile_output       ( batch_tile_output              ),
  .s_axis_tvalid           ( rd_tvalid                      ),
  .s_axis_tready           ( rd_tready                      ),
  .s_axis_tdata            ( rd_tdata                       ),
  .s_axis_tkeep            ( {C_M_AXI_DATA_WIDTH/8{1'b1}}   ),
  .s_axis_tlast            ( rd_tlast                       ),
  .m_axis_tvalid           ( adder_tvalid                   ),
  .m_axis_tready           ( adder_tready                   ),
  .m_axis_tdata            ( adder_tdata                    ),
  .m_axis_tkeep            (                                ),
  .m_axis_tlast            (                                ) 
);

// AXI4 Write Master
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_WR_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi00_write_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( write_start[0]                ) ,
  .ctrl_done               ( write_done[0]              ) ,
  .ctrl_addr_offset        ( write_addr_offset[0]       ) ,
  .ctrl_xfer_size_in_bytes ( write_xfer_byte_length[0]  ) ,
  .m_axi_awvalid           ( m00_axi_awvalid           ) ,
  .m_axi_awready           ( m00_axi_awready           ) ,
  .m_axi_awaddr            ( m00_axi_awaddr            ) ,
  .m_axi_awlen             ( m00_axi_awlen             ) ,
  .m_axi_wvalid            ( m00_axi_wvalid            ) ,
  .m_axi_wready            ( m00_axi_wready            ) ,
  .m_axi_wdata             ( m00_axi_wdata             ) ,
  .m_axi_wstrb             ( m00_axi_wstrb             ) ,
  .m_axi_wlast             ( m00_axi_wlast             ) ,
  .m_axi_bvalid            ( m00_axi_bvalid            ) ,
  .m_axi_bready            ( m00_axi_bready            ) ,
  .s_axis_aclk             ( aclk              ) ,
  .s_axis_areset           ( areset              ) ,
  .s_axis_tvalid           ( adder_tvalid[0]            ) ,
  .s_axis_tready           ( adder_tready[0]            ) ,
  .s_axis_tdata            ( adder_tdata[0]             )
);

// AXI4 Write Master
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_WR_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi01_write_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( write_start[1]                ) ,
  .ctrl_done               ( write_done[1]              ) ,
  .ctrl_addr_offset        ( write_addr_offset[1]       ) ,
  .ctrl_xfer_size_in_bytes ( write_xfer_byte_length[1]  ) ,
  .m_axi_awvalid           ( m01_axi_awvalid           ) ,
  .m_axi_awready           ( m01_axi_awready           ) ,
  .m_axi_awaddr            ( m01_axi_awaddr            ) ,
  .m_axi_awlen             ( m01_axi_awlen             ) ,
  .m_axi_wvalid            ( m01_axi_wvalid            ) ,
  .m_axi_wready            ( m01_axi_wready            ) ,
  .m_axi_wdata             ( m01_axi_wdata             ) ,
  .m_axi_wstrb             ( m01_axi_wstrb             ) ,
  .m_axi_wlast             ( m01_axi_wlast             ) ,
  .m_axi_bvalid            ( m01_axi_bvalid            ) ,
  .m_axi_bready            ( m01_axi_bready            ) ,
  .s_axis_aclk             ( aclk              ) ,
  .s_axis_areset           ( areset              ) ,
  .s_axis_tvalid           ( adder_tvalid[1]            ) ,
  .s_axis_tready           ( adder_tready[1]            ) ,
  .s_axis_tdata            ( adder_tdata[1]             )
);

// AXI4 Write Master
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_WR_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi02_write_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( write_start[2]                ) ,
  .ctrl_done               ( write_done[2]              ) ,
  .ctrl_addr_offset        ( write_addr_offset[2]       ) ,
  .ctrl_xfer_size_in_bytes ( write_xfer_byte_length[2]  ) ,
  .m_axi_awvalid           ( m02_axi_awvalid           ) ,
  .m_axi_awready           ( m02_axi_awready           ) ,
  .m_axi_awaddr            ( m02_axi_awaddr            ) ,
  .m_axi_awlen             ( m02_axi_awlen             ) ,
  .m_axi_wvalid            ( m02_axi_wvalid            ) ,
  .m_axi_wready            ( m02_axi_wready            ) ,
  .m_axi_wdata             ( m02_axi_wdata             ) ,
  .m_axi_wstrb             ( m02_axi_wstrb             ) ,
  .m_axi_wlast             ( m02_axi_wlast             ) ,
  .m_axi_bvalid            ( m02_axi_bvalid            ) ,
  .m_axi_bready            ( m02_axi_bready            ) ,
  .s_axis_aclk             ( aclk              ) ,
  .s_axis_areset           ( areset              ) ,
  .s_axis_tvalid           ( adder_tvalid[2]            ) ,
  .s_axis_tready           ( adder_tready[2]            ) ,
  .s_axis_tdata            ( adder_tdata[2]             )
);
// AXI4 Write Master
axi_write_master #(
  .C_M_AXI_ADDR_WIDTH  ( C_M_AXI_ADDR_WIDTH    ) ,
  .C_M_AXI_DATA_WIDTH  ( C_M_AXI_DATA_WIDTH    ) ,
  .C_XFER_SIZE_WIDTH   ( C_XFER_SIZE_WIDTH     ) ,
  .C_MAX_OUTSTANDING   ( LP_WR_MAX_OUTSTANDING ) ,
  .C_INCLUDE_DATA_FIFO ( 1                     )
)
inst_axi03_write_master (
  .aclk                    ( aclk                    ) ,
  .areset                  ( rst                  ) ,
  .ctrl_start              ( write_start[3]                ) ,
  .ctrl_done               ( write_done[3]              ) ,
  .ctrl_addr_offset        ( write_addr_offset[3]       ) ,
  .ctrl_xfer_size_in_bytes ( write_xfer_byte_length[3]  ) ,
  .m_axi_awvalid           ( m03_axi_awvalid           ) ,
  .m_axi_awready           ( m03_axi_awready           ) ,
  .m_axi_awaddr            ( m03_axi_awaddr            ) ,
  .m_axi_awlen             ( m03_axi_awlen             ) ,
  .m_axi_wvalid            ( m03_axi_wvalid            ) ,
  .m_axi_wready            ( m03_axi_wready            ) ,
  .m_axi_wdata             ( m03_axi_wdata             ) ,
  .m_axi_wstrb             ( m03_axi_wstrb             ) ,
  .m_axi_wlast             ( m03_axi_wlast             ) ,
  .m_axi_bvalid            ( m03_axi_bvalid            ) ,
  .m_axi_bready            ( m03_axi_bready            ) ,
  .s_axis_aclk             ( aclk              ) ,
  .s_axis_areset           ( areset              ) ,
  .s_axis_tvalid           ( adder_tvalid[3]            ) ,
  .s_axis_tready           ( adder_tready[3]            ) ,
  .s_axis_tdata            ( adder_tdata[3]             )
);
endmodule : BSW_Kernel
`default_nettype wire
