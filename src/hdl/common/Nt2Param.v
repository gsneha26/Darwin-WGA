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

//Converting nucleotide bases to the parameters from the W matrix
//
//W matrix is symmetric, hence we save the upper triangle, sub_N 
//and, gap_open and the gap_extend penalties


//    | A  | C  | G  | T
// A  | 13 | 12 | 11 | 10
// C  | 12 | 9  | 8  | 7
// G  | 11 | 8  | 6  | 5
// T  | 10 | 7  | 5  | 4
// sub_N - 3
// Gap_open - 2
// Gap_extend - 1
// numbers represent the element index of in-param
module Nt2Param #(
    parameter PE_WIDTH=16
)
(
    input [3:0] nt,
    input [13*PE_WIDTH-1:0] in_param,
    output reg [4*PE_WIDTH-1:0] out_param);

    localparam A=1, C=2, G=3, T=4, N=0;

    always @(*) begin
        case ({nt})
            A : out_param = {in_param[13*PE_WIDTH-1:9*PE_WIDTH]};
            C : out_param = {in_param[12*PE_WIDTH-1:11*PE_WIDTH], in_param[9*PE_WIDTH-1:6*PE_WIDTH]};
            G : out_param = {in_param[11*PE_WIDTH-1:10*PE_WIDTH], in_param[8*PE_WIDTH-1:7*PE_WIDTH], in_param[6*PE_WIDTH-1:4*PE_WIDTH]};
            T : out_param = {in_param[10*PE_WIDTH-1:9*PE_WIDTH], in_param[7*PE_WIDTH-1:6*PE_WIDTH], in_param[5*PE_WIDTH-1:3*PE_WIDTH]};
            N : out_param = {in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH], in_param[3*PE_WIDTH-1:2*PE_WIDTH]};
            default : out_param = {{(4*PE_WIDTH){1'b0}}};
        endcase
    end

endmodule
