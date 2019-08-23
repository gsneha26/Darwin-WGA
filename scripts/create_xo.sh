#MIT License
#
#Copyright (c) 2019 Sneha D. Goenka, Yatish Turakhia, Gill Bejerano and William Dally
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

rm -rf xclbin
mkdir xclbin

/opt/Xilinx/Vivado/2017.4.op/bin/vivado -mode batch -source ./scripts/gen_xo.tcl -tclargs xclbin/GACTX_bank3.xo GACTX $AWS_PLATFORM bank3 2
/opt/Xilinx/Vivado/2017.4.op/bin/vivado -mode batch -source ./scripts/gen_xo.tcl -tclargs xclbin/BSW_bank0.xo BSW $AWS_PLATFORM bank0 4;

for i in `seq 1 3`;
do
    cd ./src/hdl/BSW/top_modules/
    cp BSW_bank0.v   BSW_bank$i.v
    cp BSW_bank0.xml BSW_bank$i.xml
    sed -i "s/bank0/bank$i/g" BSW_bank$i.v
    sed -i "s/bank0/bank$i/g" BSW_bank$i.xml
    cd $curr_dir
    /opt/Xilinx/Vivado/2017.4.op/bin/vivado -mode batch -source ./scripts/gen_xo.tcl -tclargs xclbin/BSW_bank$i.xo BSW $AWS_PLATFORM bank$i 4;
    rm ./src/hdl/BSW/top_modules/BSW_bank$i.v ./src/hdl/BSW/top_modules/BSW_bank$i.xml
done

rm -rf packaged_kernel* tmp_kernel_pack* *.jou *.log *.wdb *.wcfg .Xil
