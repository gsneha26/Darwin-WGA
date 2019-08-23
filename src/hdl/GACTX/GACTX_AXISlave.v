// This is a generated file. Use and modify at your own risk.
////////////////////////////////////////////////////////////////////////////////

// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1ns/1ps
module GACTX_AXISlave #(
  parameter integer C_ADDR_WIDTH = 12,
  parameter integer C_DATA_WIDTH = 32
)
(
  // AXI4-Lite slave signals
  input  wire                      aclk        ,
  input  wire                      areset      ,
  input  wire                      aclk_en     ,
  input  wire                      awvalid     ,
  output wire                      awready     ,
  input  wire [C_ADDR_WIDTH-1:0]   awaddr      ,
  input  wire                      wvalid      ,
  output wire                      wready      ,
  input  wire [C_DATA_WIDTH-1:0]   wdata       ,
  input  wire [C_DATA_WIDTH/8-1:0] wstrb       ,
  input  wire                      arvalid     ,
  output wire                      arready     ,
  input  wire [C_ADDR_WIDTH-1:0]   araddr      ,
  output wire                      rvalid      ,
  input  wire                      rready      ,
  output wire [C_DATA_WIDTH-1:0]   rdata       ,
  output wire [2-1:0]              rresp       ,
  output wire                      bvalid      ,
  input  wire                      bready      ,
  output wire [2-1:0]              bresp       ,
  output wire                      interrupt   ,
  output wire                      ap_start    ,
  input  wire                      ap_idle     ,
  input  wire                      ap_done     ,
  // User defined arguments
  output wire [32-1:0]             sub_AA      ,
  output wire [32-1:0]             sub_AC      ,
  output wire [32-1:0]             sub_AG      ,
  output wire [32-1:0]             sub_AT      ,
  output wire [32-1:0]             sub_CC      ,
  output wire [32-1:0]             sub_CG      ,
  output wire [32-1:0]             sub_CT      ,
  output wire [32-1:0]             sub_GG      ,
  output wire [32-1:0]             sub_GT      ,
  output wire [32-1:0]             sub_TT      ,
  output wire [32-1:0]             sub_N       ,
  output wire [32-1:0]             gap_open    ,
  output wire [32-1:0]             gap_extend  ,
  output wire [32-1:0]             y_drop      ,
  output wire [32-1:0]             align_fields,
  output wire [32-1:0]             ref_len     ,
  output wire [32-1:0]             query_len   ,
  output wire [64-1:0]             ref_offset  ,
  output wire [64-1:0]             query_offset,
  output wire [64-1:0]             ref_seq     ,
  output wire [64-1:0]             query_seq   ,
  output wire [64-1:0]             tile_output ,
  output wire [64-1:0]             tb_output   
);

//------------------------Address Info-------------------
// 0x000 : Control signals
//         bit 0  - ap_start (Read/Write/COH)
//         bit 1  - ap_done (Read/COR)
//         bit 2  - ap_idle (Read)
//         others - reserved
// 0x004 : Global Interrupt Enable Register
//         bit 0  - Global Interrupt Enable (Read/Write)
//         others - reserved
// 0x008 : IP Interrupt Enable Register (Read/Write)
//         bit 0  - Channel 0 (ap_done)
//         others - reserved
// 0x00c : IP Interrupt Status Register (Read/TOW)
//         bit 0  - Channel 0 (ap_done)
//         others - reserved
// 0x010 : Data signal of sub_AA
//         bit 31~0 - sub_AA[31:0] (Read/Write)
// 0x014 : reserved
// 0x018 : Data signal of sub_AC
//         bit 31~0 - sub_AC[31:0] (Read/Write)
// 0x01c : reserved
// 0x020 : Data signal of sub_AG
//         bit 31~0 - sub_AG[31:0] (Read/Write)
// 0x024 : reserved
// 0x028 : Data signal of sub_AT
//         bit 31~0 - sub_AT[31:0] (Read/Write)
// 0x02c : reserved
// 0x030 : Data signal of sub_CC
//         bit 31~0 - sub_CC[31:0] (Read/Write)
// 0x034 : reserved
// 0x038 : Data signal of sub_CG
//         bit 31~0 - sub_CG[31:0] (Read/Write)
// 0x03c : reserved
// 0x040 : Data signal of sub_CT
//         bit 31~0 - sub_CT[31:0] (Read/Write)
// 0x044 : reserved
// 0x048 : Data signal of sub_GG
//         bit 31~0 - sub_GG[31:0] (Read/Write)
// 0x04c : reserved
// 0x050 : Data signal of sub_GT
//         bit 31~0 - sub_GT[31:0] (Read/Write)
// 0x054 : reserved
// 0x058 : Data signal of sub_TT
//         bit 31~0 - sub_TT[31:0] (Read/Write)
// 0x05c : reserved
// 0x060 : Data signal of sub_N
//         bit 31~0 - sub_N[31:0] (Read/Write)
// 0x064 : reserved
// 0x068 : Data signal of gap_open
//         bit 31~0 - gap_open[31:0] (Read/Write)
// 0x06c : reserved
// 0x070 : Data signal of gap_extend
//         bit 31~0 - gap_extend[31:0] (Read/Write)
// 0x074 : reserved
// 0x078 : Data signal of y_drop
//         bit 31~0 - y_drop[31:0] (Read/Write)
// 0x07c : reserved
// 0x080 : Data signal of align_fields
//         bit 31~0 - align_fields[31:0] (Read/Write)
// 0x084 : reserved
// 0x088 : Data signal of ref_len
//         bit 31~0 - ref_len[31:0] (Read/Write)
// 0x08c : reserved
// 0x090 : Data signal of query_len
//         bit 31~0 - query_len[31:0] (Read/Write)
// 0x094 : reserved
// 0x098 : Data signal of ref_offset
//         bit 31~0 - ref_offset[31:0] (Read/Write)
// 0x09c : Data signal of ref_offset
//         bit 31~0 - ref_offset[63:32] (Read/Write)
// 0x0a0 : Data signal of query_offset
//         bit 31~0 - query_offset[31:0] (Read/Write)
// 0x0a4 : Data signal of query_offset
//         bit 31~0 - query_offset[63:32] (Read/Write)
// 0x0a8 : Data signal of ref_seq
//         bit 31~0 - ref_seq[31:0] (Read/Write)
// 0x0ac : Data signal of ref_seq
//         bit 31~0 - ref_seq[63:32] (Read/Write)
// 0x0b0 : Data signal of query_seq
//         bit 31~0 - query_seq[31:0] (Read/Write)
// 0x0b4 : Data signal of query_seq
//         bit 31~0 - query_seq[63:32] (Read/Write)
// 0x0b8 : Data signal of tile_output
//         bit 31~0 - tile_output[31:0] (Read/Write)
// 0x0bc : Data signal of tile_output
//         bit 31~0 - tile_output[63:32] (Read/Write)
// 0x0c0 : Data signal of tb_output
//         bit 31~0 - tb_output[31:0] (Read/Write)
// 0x0c4 : Data signal of tb_output
//         bit 31~0 - tb_output[63:32] (Read/Write)
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_AP_CTRL                = 12'h000;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_GIE                    = 12'h004;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_IER                    = 12'h008;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_ISR                    = 12'h00c;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_AA_0               = 12'h010;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_AC_0               = 12'h018;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_AG_0               = 12'h020;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_AT_0               = 12'h028;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_CC_0               = 12'h030;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_CG_0               = 12'h038;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_CT_0               = 12'h040;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_GG_0               = 12'h048;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_GT_0               = 12'h050;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_TT_0               = 12'h058;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_SUB_N_0                = 12'h060;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_GAP_OPEN_0             = 12'h068;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_GAP_EXTEND_0           = 12'h070;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_Y_DROP_0               = 12'h078;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_ALIGN_FIELDS_0         = 12'h080;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_REF_LEN_0              = 12'h088;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_QUERY_LEN_0            = 12'h090;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_REF_OFFSET_0           = 12'h098;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_REF_OFFSET_1           = 12'h09c;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_QUERY_OFFSET_0         = 12'h0a0;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_QUERY_OFFSET_1         = 12'h0a4;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_ref_seq_0              = 12'h0a8;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_ref_seq_1              = 12'h0ac;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_query_seq_0            = 12'h0b0;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_query_seq_1            = 12'h0b4;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_tile_output_0          = 12'h0b8;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_tile_output_1          = 12'h0bc;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_tb_output_0            = 12'h0c0;
localparam [C_ADDR_WIDTH-1:0]       LP_ADDR_tb_output_1            = 12'h0c4;
localparam integer                  LP_SM_WIDTH                    = 2;
localparam [LP_SM_WIDTH-1:0]        SM_WRIDLE                      = 2'd0;
localparam [LP_SM_WIDTH-1:0]        SM_WRDATA                      = 2'd1;
localparam [LP_SM_WIDTH-1:0]        SM_WRRESP                      = 2'd2;
localparam [LP_SM_WIDTH-1:0]        SM_RDIDLE                      = 2'd0;
localparam [LP_SM_WIDTH-1:0]        SM_RDDATA                      = 2'd1;

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
reg  [LP_SM_WIDTH-1:0]              wstate                         = SM_WRIDLE;
reg  [LP_SM_WIDTH-1:0]              wnext                         ;
reg  [C_ADDR_WIDTH-1:0]             waddr                         ;
wire [C_DATA_WIDTH-1:0]             wmask                         ;
wire                                aw_hs                         ;
wire                                w_hs                          ;
reg  [LP_SM_WIDTH-1:0]              rstate                         = SM_RDIDLE;
reg  [LP_SM_WIDTH-1:0]              rnext                         ;
reg  [C_DATA_WIDTH-1:0]             rdata_r                       ;
wire                                ar_hs                         ;
wire [C_ADDR_WIDTH-1:0]             raddr                         ;
// internal registers
wire                                int_ap_idle                   ;
reg                                 int_ap_done                    = 1'b0;
reg                                 int_ap_start                   = 1'b0;
reg                                 int_gie                        = 1'b0;
reg                                 int_ier                        = 1'b0;
reg                                 int_isr                        = 1'b0;

reg  [32-1:0]                       int_sub_AA                     = 32'd0;
reg  [32-1:0]                       int_sub_AC                     = 32'd0;
reg  [32-1:0]                       int_sub_AG                     = 32'd0;
reg  [32-1:0]                       int_sub_AT                     = 32'd0;
reg  [32-1:0]                       int_sub_CC                     = 32'd0;
reg  [32-1:0]                       int_sub_CG                     = 32'd0;
reg  [32-1:0]                       int_sub_CT                     = 32'd0;
reg  [32-1:0]                       int_sub_GG                     = 32'd0;
reg  [32-1:0]                       int_sub_GT                     = 32'd0;
reg  [32-1:0]                       int_sub_TT                     = 32'd0;
reg  [32-1:0]                       int_sub_N                      = 32'd0;
reg  [32-1:0]                       int_gap_open                   = 32'd0;
reg  [32-1:0]                       int_gap_extend                 = 32'd0;
reg  [32-1:0]                       int_y_drop                     = 32'd0;
reg  [32-1:0]                       int_align_fields               = 32'd0;
reg  [32-1:0]                       int_ref_len                    = 32'd0;
reg  [32-1:0]                       int_query_len                  = 32'd0;
reg  [64-1:0]                       int_ref_offset                 = 64'd0;
reg  [64-1:0]                       int_query_offset               = 64'd0;
reg  [64-1:0]                       int_ref_seq                    = 64'd0;
reg  [64-1:0]                       int_query_seq                  = 64'd0;
reg  [64-1:0]                       int_tile_output                = 64'd0;
reg  [64-1:0]                       int_tb_output                  = 64'd0;

///////////////////////////////////////////////////////////////////////////////
// Begin RTL
///////////////////////////////////////////////////////////////////////////////

//------------------------AXI write fsm------------------
assign awready = (~areset) & (wstate == SM_WRIDLE);
assign wready  = (wstate == SM_WRDATA);
assign bresp   = 2'b00;  // OKAY
assign bvalid  = (wstate == SM_WRRESP);
assign wmask   = { {8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}} };
assign aw_hs   = awvalid & awready;
assign w_hs    = wvalid & wready;

// wstate
always @(posedge aclk) begin
  if (areset)
    wstate <= SM_WRIDLE;
  else if (aclk_en)
    wstate <= wnext;
end

// wnext
always @(*) begin
  case (wstate)
    SM_WRIDLE:
      if (awvalid)
        wnext = SM_WRDATA;
      else
        wnext = SM_WRIDLE;
    SM_WRDATA:
      if (wvalid)
        wnext = SM_WRRESP;
      else
        wnext = SM_WRDATA;
    SM_WRRESP:
      if (bready)
        wnext = SM_WRIDLE;
      else
        wnext = SM_WRRESP;
    default:
      wnext = SM_WRIDLE;
  endcase
end

// waddr
always @(posedge aclk) begin
  if (aclk_en) begin
    if (aw_hs)
      waddr <= awaddr;
  end
end

//------------------------AXI read fsm-------------------
assign arready = (~areset) && (rstate == SM_RDIDLE);
assign rdata   = rdata_r;
assign rresp   = 2'b00;  // OKAY
assign rvalid  = (rstate == SM_RDDATA);
assign ar_hs   = arvalid & arready;
assign raddr   = araddr;

// rstate
always @(posedge aclk) begin
  if (areset)
    rstate <= SM_RDIDLE;
  else if (aclk_en)
    rstate <= rnext;
end

// rnext
always @(*) begin
  case (rstate)
    SM_RDIDLE:
      if (arvalid)
        rnext = SM_RDDATA;
      else
        rnext = SM_RDIDLE;
    SM_RDDATA:
      if (rready & rvalid)
        rnext = SM_RDIDLE;
      else
        rnext = SM_RDDATA;
    default:
      rnext = SM_RDIDLE;
  endcase
end

// rdata_r
always @(posedge aclk) begin
  if (aclk_en) begin
    if (ar_hs) begin
      rdata_r <= {C_DATA_WIDTH{1'b0}};
      case (raddr)
        LP_ADDR_AP_CTRL: begin
          rdata_r[0] <= int_ap_start;
          rdata_r[1] <= int_ap_done;
          rdata_r[2] <= int_ap_idle;
          rdata_r[3+:C_DATA_WIDTH-3] <= {C_DATA_WIDTH-3{1'b0}};
        end
        LP_ADDR_GIE: begin
          rdata_r[0] <= int_gie;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_IER: begin
          rdata_r[0] <= int_ier;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_ISR: begin
          rdata_r[0] <= int_isr;
          rdata_r[1+:C_DATA_WIDTH-1] <=  {C_DATA_WIDTH-1{1'b0}};
        end
        LP_ADDR_SUB_AA_0: begin
          rdata_r <= int_sub_AA[0+:32];
        end
        LP_ADDR_SUB_AC_0: begin
          rdata_r <= int_sub_AC[0+:32];
        end
        LP_ADDR_SUB_AG_0: begin
          rdata_r <= int_sub_AG[0+:32];
        end
        LP_ADDR_SUB_AT_0: begin
          rdata_r <= int_sub_AT[0+:32];
        end
        LP_ADDR_SUB_CC_0: begin
          rdata_r <= int_sub_CC[0+:32];
        end
        LP_ADDR_SUB_CG_0: begin
          rdata_r <= int_sub_CG[0+:32];
        end
        LP_ADDR_SUB_CT_0: begin
          rdata_r <= int_sub_CT[0+:32];
        end
        LP_ADDR_SUB_GG_0: begin
          rdata_r <= int_sub_GG[0+:32];
        end
        LP_ADDR_SUB_GT_0: begin
          rdata_r <= int_sub_GT[0+:32];
        end
        LP_ADDR_SUB_TT_0: begin
          rdata_r <= int_sub_TT[0+:32];
        end
        LP_ADDR_SUB_N_0: begin
          rdata_r <= int_sub_N[0+:32];
        end
        LP_ADDR_GAP_OPEN_0: begin
          rdata_r <= int_gap_open[0+:32];
        end
        LP_ADDR_GAP_EXTEND_0: begin
          rdata_r <= int_gap_extend[0+:32];
        end
        LP_ADDR_Y_DROP_0: begin
          rdata_r <= int_y_drop[0+:32];
        end
        LP_ADDR_ALIGN_FIELDS_0: begin
          rdata_r <= int_align_fields[0+:32];
        end
        LP_ADDR_REF_LEN_0: begin
          rdata_r <= int_ref_len[0+:32];
        end
        LP_ADDR_QUERY_LEN_0: begin
          rdata_r <= int_query_len[0+:32];
        end
        LP_ADDR_REF_OFFSET_0: begin
          rdata_r <= int_ref_offset[0+:32];
        end
        LP_ADDR_REF_OFFSET_1: begin
          rdata_r <= int_ref_offset[32+:32];
        end
        LP_ADDR_QUERY_OFFSET_0: begin
          rdata_r <= int_query_offset[0+:32];
        end
        LP_ADDR_QUERY_OFFSET_1: begin
          rdata_r <= int_query_offset[32+:32];
        end
        LP_ADDR_ref_seq_0: begin
          rdata_r <= int_ref_seq[0+:32];
        end
        LP_ADDR_ref_seq_1: begin
          rdata_r <= int_ref_seq[32+:32];
        end
        LP_ADDR_query_seq_0: begin
          rdata_r <= int_query_seq[0+:32];
        end
        LP_ADDR_query_seq_1: begin
          rdata_r <= int_query_seq[32+:32];
        end
        LP_ADDR_tile_output_0: begin
          rdata_r <= int_tile_output[0+:32];
        end
        LP_ADDR_tile_output_1: begin
          rdata_r <= int_tile_output[32+:32];
        end
        LP_ADDR_tb_output_0: begin
          rdata_r <= int_tb_output[0+:32];
        end
        LP_ADDR_tb_output_1: begin
          rdata_r <= int_tb_output[32+:32];
        end

        default: begin
          rdata_r <= {C_DATA_WIDTH{1'b0}};
        end
      endcase
    end
  end
end

//------------------------Register logic-----------------
assign interrupt    = int_gie & (|int_isr);
assign ap_start     = int_ap_start;
assign int_ap_idle  = ap_idle;
assign sub_AA = int_sub_AA;
assign sub_AC = int_sub_AC;
assign sub_AG = int_sub_AG;
assign sub_AT = int_sub_AT;
assign sub_CC = int_sub_CC;
assign sub_CG = int_sub_CG;
assign sub_CT = int_sub_CT;
assign sub_GG = int_sub_GG;
assign sub_GT = int_sub_GT;
assign sub_TT = int_sub_TT;
assign sub_N = int_sub_N;
assign gap_open = int_gap_open;
assign gap_extend = int_gap_extend;
assign y_drop = int_y_drop;
assign align_fields = int_align_fields;
assign ref_len = int_ref_len;
assign query_len = int_query_len;
assign ref_offset = int_ref_offset;
assign query_offset = int_query_offset;
assign ref_seq = int_ref_seq;
assign query_seq = int_query_seq;
assign tile_output = int_tile_output;
assign tb_output = int_tb_output;

// int_ap_start
always @(posedge aclk) begin
  if (areset)
    int_ap_start <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_AP_CTRL && wstrb[0] && wdata[0])
      int_ap_start <= 1'b1;
    else if (ap_done)
      int_ap_start <= 1'b0;
  end
end

// int_ap_done
always @(posedge aclk) begin
  if (areset)
    int_ap_done <= 1'b0;
  else if (aclk_en) begin
    if (ap_done)
      int_ap_done <= 1'b1;
    else if (ar_hs && raddr == LP_ADDR_AP_CTRL)
      int_ap_done <= 1'b0; // clear on read
  end
end

// int_gie
always @(posedge aclk) begin
  if (areset)
    int_gie     <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_GIE && wstrb[0])
      int_gie <= wdata[0];
  end
end

// int_ier
always @(posedge aclk) begin
  if (areset)
    int_ier     <= 1'b0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_IER && wstrb[0])
      int_ier <= wdata[0];
  end
end

// int_isr
always @(posedge aclk) begin
  if (areset)
    int_isr     <= 1'b0;
  else if (aclk_en) begin
    if (int_ier & ap_done)
      int_isr <= 1'b1;
    else if (w_hs && waddr == LP_ADDR_ISR && wstrb[0])
      int_isr <= int_isr ^ wdata[0];
  end
end


// int_sub_AA[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_AA[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_AA_0)
      int_sub_AA[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_AA[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_AC[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_AC[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_AC_0)
      int_sub_AC[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_AC[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_AG[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_AG[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_AG_0)
      int_sub_AG[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_AG[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_AT[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_AT[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_AT_0)
      int_sub_AT[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_AT[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_CC[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_CC[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_CC_0)
      int_sub_CC[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_CC[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_CG[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_CG[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_CG_0)
      int_sub_CG[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_CG[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_CT[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_CT[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_CT_0)
      int_sub_CT[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_CT[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_GG[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_GG[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_GG_0)
      int_sub_GG[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_GG[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_GT[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_GT[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_GT_0)
      int_sub_GT[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_GT[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_TT[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_TT[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_TT_0)
      int_sub_TT[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_TT[0+:32] & ~wmask[0+:32]);
  end
end

// int_sub_N[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_sub_N[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_SUB_N_0)
      int_sub_N[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_sub_N[0+:32] & ~wmask[0+:32]);
  end
end

// int_gap_open[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_gap_open[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_GAP_OPEN_0)
      int_gap_open[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_gap_open[0+:32] & ~wmask[0+:32]);
  end
end

// int_gap_extend[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_gap_extend[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_GAP_EXTEND_0)
      int_gap_extend[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_gap_extend[0+:32] & ~wmask[0+:32]);
  end
end

// int_y_drop[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_y_drop[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_Y_DROP_0)
      int_y_drop[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_y_drop[0+:32] & ~wmask[0+:32]);
  end
end

// int_align_fields[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_align_fields[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_ALIGN_FIELDS_0)
      int_align_fields[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_align_fields[0+:32] & ~wmask[0+:32]);
  end
end

// int_ref_len[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_ref_len[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_REF_LEN_0)
      int_ref_len[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_ref_len[0+:32] & ~wmask[0+:32]);
  end
end

// int_query_len[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_query_len[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_QUERY_LEN_0)
      int_query_len[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_query_len[0+:32] & ~wmask[0+:32]);
  end
end

// int_ref_offset[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_ref_offset[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_REF_OFFSET_0)
      int_ref_offset[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_ref_offset[0+:32] & ~wmask[0+:32]);
  end
end

// int_ref_offset[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_ref_offset[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_REF_OFFSET_1)
      int_ref_offset[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_ref_offset[32+:32] & ~wmask[0+:32]);
  end
end

// int_query_offset[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_query_offset[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_QUERY_OFFSET_0)
      int_query_offset[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_query_offset[0+:32] & ~wmask[0+:32]);
  end
end

// int_query_offset[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_query_offset[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_QUERY_OFFSET_1)
      int_query_offset[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_query_offset[32+:32] & ~wmask[0+:32]);
  end
end

// int_ref_seq[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_ref_seq[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_ref_seq_0)
      int_ref_seq[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_ref_seq[0+:32] & ~wmask[0+:32]);
  end
end

// int_ref_seq[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_ref_seq[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_ref_seq_1)
      int_ref_seq[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_ref_seq[32+:32] & ~wmask[0+:32]);
  end
end

// int_query_seq[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_query_seq[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_query_seq_0)
      int_query_seq[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_query_seq[0+:32] & ~wmask[0+:32]);
  end
end

// int_query_seq[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_query_seq[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_query_seq_1)
      int_query_seq[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_query_seq[32+:32] & ~wmask[0+:32]);
  end
end

// int_tile_output[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_tile_output[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_tile_output_0)
      int_tile_output[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_tile_output[0+:32] & ~wmask[0+:32]);
  end
end

// int_tile_output[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_tile_output[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_tile_output_1)
      int_tile_output[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_tile_output[32+:32] & ~wmask[0+:32]);
  end
end

// int_tb_output[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_tb_output[0+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_tb_output_0)
      int_tb_output[0+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_tb_output[0+:32] & ~wmask[0+:32]);
  end
end

// int_tb_output[32-1:0]
always @(posedge aclk) begin
  if (areset)
    int_tb_output[32+:32] <= 32'd0;
  else if (aclk_en) begin
    if (w_hs && waddr == LP_ADDR_tb_output_1)
      int_tb_output[32+:32] <= (wdata[0+:32] & wmask[0+:32]) | (int_tb_output[32+:32] & ~wmask[0+:32]);
  end
end


endmodule

`default_nettype wire

