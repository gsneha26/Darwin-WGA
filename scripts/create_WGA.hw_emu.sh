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

rm -rf test_WGA_hw_emu
cp -r ./src/host/WGA ./test_WGA_hw_emu
cp ./src/host/common/* ./test_WGA_hw_emu/

xocc -g --target hw_emu --platform $AWS_PLATFORM --link \
    --nk BSW_bank0:1 \
    --sp BSW_bank0_1.m00_axi:bank0 \
    --sp BSW_bank0_1.m01_axi:bank0 \
    --sp BSW_bank0_1.m02_axi:bank0 \
    --sp BSW_bank0_1.m03_axi:bank0 \
    --nk BSW_bank1:1 \
    --sp BSW_bank1_1.m00_axi:bank1 \
    --sp BSW_bank1_1.m01_axi:bank1 \
    --sp BSW_bank1_1.m02_axi:bank1 \
    --sp BSW_bank1_1.m03_axi:bank1 \
    --nk BSW_bank2:1 \
    --sp BSW_bank2_1.m00_axi:bank2 \
    --sp BSW_bank2_1.m01_axi:bank2 \
    --sp BSW_bank2_1.m02_axi:bank2 \
    --sp BSW_bank2_1.m03_axi:bank2 \
    --nk BSW_bank3:1 \
    --sp BSW_bank3_1.m00_axi:bank3 \
    --sp BSW_bank3_1.m01_axi:bank3 \
    --sp BSW_bank3_1.m02_axi:bank3 \
    --sp BSW_bank3_1.m03_axi:bank3 \
    --nk GACTX_bank3:1 \
    --sp GACTX_bank3_1.m00_axi:bank3 \
    --sp GACTX_bank3_1.m01_axi:bank3 \
    --output test_WGA_hw_emu/WGA.hw_emu.xclbin xclbin/BSW_bank0.xo xclbin/BSW_bank1.xo xclbin/BSW_bank2.xo xclbin/BSW_bank3.xo xclbin/GACTX_bank3.xo
rm -rf *.dir *.cf *.dat

cd $curr_dir
rm -rf packaged_kernel* tmp_kernel_pack* *.jou *.log *.wdb *.wcfg .Xil

cd ./test_WGA_hw_emu

cmake -DCMAKE_BUILD_TYPE=Release -DTBB_ROOT=${PROJECT_DIR}/tbb -DAWS_PLATFORM=${AWS_PLATFORM} -DXILINX_SDX=${XILINX_SDX} -DXILINX_VIVADO=${XILINX_VIVADO} .
make
