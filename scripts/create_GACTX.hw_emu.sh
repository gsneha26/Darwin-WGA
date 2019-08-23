#MIT License
#
#Copyright (c) 2019 Sneha D. Goenka, Yatish Turakhia, Gill Bejerano and William J. Dally
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

curr_dir=$PWD

rm -rf test_GACTX_hw_emu
cp -r ./src/host/GACTX ./test_GACTX_hw_emu
cp ./src/host/common/* ./test_GACTX_hw_emu/

xocc -g --target hw_emu --platform $AWS_PLATFORM --link \
    --nk GACTX_bank3:1 \
    --sp GACTX_bank3_1.m00_axi:bank3 \
    --sp GACTX_bank3_1.m01_axi:bank3 \
    --output test_GACTX_hw_emu/GACTX.hw_emu.xclbin xclbin/GACTX_bank3.xo
rm -rf *.dir *.cf *.dat

cd $curr_dir
rm -rf packaged_kernel* tmp_kernel_pack* *.jou *.log *.wdb *.wcfg .Xil

cd ./test_GACTX_hw_emu

cmake -DCMAKE_BUILD_TYPE=Release -DAWS_PLATFORM=${AWS_PLATFORM} -DXILINX_SDX=${XILINX_SDX} -DXILINX_VIVADO=${XILINX_VIVADO} .
make
