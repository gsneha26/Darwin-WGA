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

module FIFO#(
    parameter integer DATA_WIDTH = 8, 
    parameter integer ADDR_WIDTH = 4
)(    
    input clk, 
    input rst, 
    input [DATA_WIDTH-1:0] in, 
    input wr_en, 
    input rd_en, 
    output [DATA_WIDTH-1:0] out, 
    output full, 
    output empty
);
parameter DEPTH = (2 ** ADDR_WIDTH);

reg [ADDR_WIDTH-1:0] head, tail;
reg [ADDR_WIDTH-1:0] total;

DP_BRAM #(
    .DATA_WIDTH(DATA_WIDTH), 
    .ADDR_WIDTH(ADDR_WIDTH)
) mem(
    .clk(clk), 
    .data_in(in), 
    .waddr(tail),
    .wr_en(wr_en), 
    .data_out(out), 
    .raddr(head)
);

assign full = (total == (DEPTH-1)); 
assign empty = (total==0);

always@(posedge clk) begin
    if(rst) begin
        tail <= {ADDR_WIDTH{1'b0}}; 
        head <= {ADDR_WIDTH{1'b0}}; 
        total <= {ADDR_WIDTH{1'b0}};
    end
    else begin
        if(wr_en) begin
            tail <= tail + 1;
        end

        if(rd_en) begin
            head <= head + 1;
        end

        if(rd_en == 1 && wr_en == 0) begin
            total <= total - 1;
        end

        if(rd_en == 0 && wr_en == 1) begin
            total <= total + 1;
        end
    end
end
endmodule

