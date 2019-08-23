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

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <algorithm>
#include <math.h>
#include <unistd.h>
#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <CL/opencl.h>
#include <CL/cl_ext.h>
#include "ConfigFile.h"
#include "Chameleon.h"
#include <iostream>
#include <fstream>

////////////////////////////////////////////////////////////////////////////////
struct Configuration {
    //FASTA files
    std::string reference_name;
    std::string query_name;
    std::string reference_filename;
    std::string query_filename;

    // Scoring
    int sub_mat[11];
    int gap_open;
    int gap_extend;

    // GACT-X
    int ydrop;

    // Output
    std::string output_filename;
};


#if defined(SDX_PLATFORM) && !defined(TARGET_DEVICE)
#define STR_VALUE(arg)      #arg
#define GET_STRING(name) STR_VALUE(name)
#define TARGET_DEVICE GET_STRING(SDX_PLATFORM)
#endif

#define TB_MASK (1 << 2)-1
#define Z 0
#define I 1
#define D 2
#define M 3

////////////////////////////////////////////////////////////////////////////////

int load_file_to_memory(const char *filename, char **result){
    uint size = 0;
    FILE *f = fopen(filename, "rb");
    if (f == NULL) {
        *result = NULL;
        return -1; // -1 means file opening fail
    }
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);
    *result = (char *)malloc(size+1);
    if (size != fread(*result, sizeof(char), size, f)) {
        free(*result);
        return -2; // -2 means file reading fail
    }
    fclose(f);
    (*result)[size] = 0;
    return size;
}

int main(int argc, char** argv){

    if (argc != 2) {
        printf("Usage: %s xclbin\n", argv[0]);
        return EXIT_FAILURE;
    }

    char *xclbin = argv[1];

    int err;                            // error code returned from api calls

    //////////////////////////////////////////////////////////////////////////
    // Configuration and Setup
    //////////////////////////////////////////////////////////////////////////

    cl_platform_id platform_id;         // platform id
    cl_device_id device_id;             // compute device id
    cl_context context;                 // compute context
    cl_command_queue commands;          // compute command queue
    cl_program program;                 // compute programs
    cl_kernel kernel;                   // compute kernel

    char cl_platform_vendor[1001];
    char target_device_name[1001] = TARGET_DEVICE;

    cl_mem ref_seq;
    cl_mem query_seq;

    // Get all platforms and then select Xilinx platform
    cl_platform_id platforms[16];       // platform id
    cl_uint platform_count;
    int platform_found = 0;
    err = clGetPlatformIDs(16, platforms, &platform_count);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to find an OpenCL platform!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Find Xilinx Plaftorm
    for (unsigned int iplat=0; iplat<platform_count; iplat++) {
        err = clGetPlatformInfo(platforms[iplat], CL_PLATFORM_VENDOR, 1000, (void *)cl_platform_vendor,NULL);
        if (err != CL_SUCCESS) {
            printf("Error: clGetPlatformInfo(CL_PLATFORM_VENDOR) failed!\n");
            printf("Test failed\n");
            return EXIT_FAILURE;
        }
        if (strcmp(cl_platform_vendor, "Xilinx") == 0) {
            platform_id = platforms[iplat];
            platform_found = 1;
        }
    }
    if (!platform_found) {
        printf("ERROR: Platform Xilinx not found. Exit.\n");
        return EXIT_FAILURE;
    }

   // Get Accelerator compute device
    cl_uint num_devices;
    unsigned int device_found = 0;
    cl_device_id devices[16];  // compute device id
    char cl_device_name[1001];
    err = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_ACCELERATOR, 16, devices, &num_devices);
    if (err != CL_SUCCESS) {
        printf("ERROR: Failed to create a device group!\n");
        printf("ERROR: Test failed\n");
        return -1;
    }

    //iterate all devices to select the target device.
    for (uint i=0; i<num_devices; i++) {
        err = clGetDeviceInfo(devices[i], CL_DEVICE_NAME, 1024, cl_device_name, 0);
        if (err != CL_SUCCESS) {
            printf("Error: Failed to get device name for device %d!\n", i);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }
        if(strcmp(cl_device_name, target_device_name) == 0) {
            device_id = devices[i];
            device_found = 1;
       }
    }

    if (!device_found) {
        printf("Target device %s not found. Exit.\n", target_device_name);
        return EXIT_FAILURE;
    }

    // Create a compute context
    context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
    if (!context) {
        printf("Error: Failed to create a compute context!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Create a command commands
    commands = clCreateCommandQueue(context, device_id, 0, &err);
    if (!commands) {
        printf("Error: Failed to create a command commands!\n");
        printf("Error: code %i\n",err);
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    int status;

    // Create Program Objects
    unsigned char *kernelbinary;

    // Load binary from disk
    int n_i0 = load_file_to_memory(xclbin, (char **) &kernelbinary);
    if (n_i0 < 0) {
        printf("failed to load kernel from xclbin: %s\n", xclbin);
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    size_t n0 = n_i0;

    // Create the compute program from offline
    program = clCreateProgramWithBinary(context, 1, &device_id, &n0,
                                        (const unsigned char **) &kernelbinary, &status, &err);

    if ((!program) || (err!=CL_SUCCESS)) {
        printf("Error: Failed to create compute program from binary %d!\n", err);
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Build the program executable
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err != CL_SUCCESS) {
        size_t len;
        char buffer[2048];

        printf("Error: Failed to build program executable!\n");
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
        printf("%s\n", buffer);
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Create the compute kernel in the program we wish to run
     kernel = clCreateKernel(program, "GACTX_bank3", &err);
    if (!kernel || err != CL_SUCCESS) {
        printf("Error: Failed to create compute kernel!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Create structs to define memory bank mapping
    cl_mem_ext_ptr_t bank3_ext;

    bank3_ext.flags = XCL_MEM_DDR_BANK3;
    bank3_ext.obj = NULL;
    bank3_ext.param = 0;

    Configuration cfg;
    ConfigFile cfg_file("params.cfg");

    // FASTA files
    cfg.reference_name     = (std::string) cfg_file.Value("FASTA_files", "reference_name"); 
    cfg.reference_filename = (std::string) cfg_file.Value("FASTA_files", "reference_filename"); 
    cfg.query_name         = (std::string) cfg_file.Value("FASTA_files", "query_name"); 
    cfg.query_filename     = (std::string) cfg_file.Value("FASTA_files", "query_filename"); 

    // Scoring
    cfg.sub_mat[0]      = cfg_file.Value("Scoring", "sub_AA");
    cfg.sub_mat[1]      = cfg_file.Value("Scoring", "sub_AC");
    cfg.sub_mat[2]      = cfg_file.Value("Scoring", "sub_AG");
    cfg.sub_mat[3]      = cfg_file.Value("Scoring", "sub_AT");
    cfg.sub_mat[4]      = cfg_file.Value("Scoring", "sub_CC");
    cfg.sub_mat[5]      = cfg_file.Value("Scoring", "sub_CG");
    cfg.sub_mat[6]      = cfg_file.Value("Scoring", "sub_CT");
    cfg.sub_mat[7]      = cfg_file.Value("Scoring", "sub_GG");
    cfg.sub_mat[8]      = cfg_file.Value("Scoring", "sub_GT");
    cfg.sub_mat[9]      = cfg_file.Value("Scoring", "sub_TT");
    cfg.sub_mat[10]     = cfg_file.Value("Scoring", "sub_N");
    cfg.gap_open        = cfg_file.Value("Scoring", "gap_open");
    cfg.gap_extend      = cfg_file.Value("Scoring", "gap_extend");
    cfg.ydrop           = cfg_file.Value("GACTX_params", "ydrop");

    //Output
    cfg.output_filename = (std::string) cfg_file.Value("Output", "output_filename");

    int ref_len;
    int query_len;
    long ref_offset;
    long query_offset;
    int align_fields;

    std::string ref;
    std::string query;
    std::ifstream infile;

    infile.open (cfg.reference_filename);
    getline(infile, ref);
    infile.close();

    infile.open (cfg.query_filename);
    getline(infile, query);
    infile.close();

    int r_len = ref.length();
    int q_len = query.length();

    char h_ref_seq_input[r_len];
    char h_query_seq_input[q_len];

    int k = 0;
    for(k = 0; k < r_len; k++){
        h_ref_seq_input[k] = ref[r_len-1-k];
    }
    
    for(k = 0; k < q_len; k++){
        h_query_seq_input[k] = query[q_len-1-k];
    }

    cl_event writeevent;

    ref_seq = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * r_len, &bank3_ext, NULL);
    query_seq = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * q_len, &bank3_ext, NULL);
    if (!(ref_seq&&query_seq)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    err = clEnqueueWriteBuffer(commands, ref_seq, CL_TRUE, 0, sizeof(char) * r_len, h_ref_seq_input, 0, NULL, &writeevent);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }
    clWaitForEvents(1, &writeevent); 

    err = clEnqueueWriteBuffer(commands, query_seq, CL_TRUE, 0, sizeof(char) * q_len, h_query_seq_input, 0, NULL, &writeevent);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    clWaitForEvents(1, &writeevent); 

    ////////////////////////////////////
    cl_event readevent;

    infile.open("parameters.txt");
    while(!infile.eof()){

        std::string param; 

        ref_len = -10;
        query_len = -10;
        ref_offset = -10;
        query_offset = -10;
        align_fields = -10;

        getline(infile, param, ' ' );
        ref_len = stoi(param);

        getline(infile, param, ' ' );
        query_len = stoi(param);

        getline(infile, param, ' ' );
        ref_offset = stol(param);
        
        getline(infile, param, ' ' );
        query_offset = stol(param);
        
        getline(infile, param, ' ' );
        align_fields = stoi(param);

        int max_tb = (ref_len + query_len)*2/32;
        int h_tile_output[16];
        int h_tb_output[max_tb];

        // Fill our data sets with pattern
        int i = 0;
        for(i = 0; i < 16; i++) {
            h_tile_output[i] = 0; 
        }

        for(i = 0; i < max_tb; i++) {
            h_tb_output[i]  = 33;
        }

        // Create the input and output arrays in device memory for our calculation
        cl_mem tile_output = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(int) * 16, &bank3_ext, NULL);
        cl_mem tb_output = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(int) * max_tb, &bank3_ext, NULL);

        if (!(tile_output&&tb_output)) {
            printf("Error: Failed to allocate device memory!\n");
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

        // Write our data set into the input array in device memory
        err = clEnqueueWriteBuffer(commands, tile_output, CL_TRUE, 0, sizeof(int) * 16, h_tile_output, 0, NULL, &writeevent);
        if (err != CL_SUCCESS) {
            printf("Error: Failed to write to source array h_tb_output_input!\n");
            printf("Test failed\n");
            return EXIT_FAILURE;
        }
        clWaitForEvents(1, &writeevent); 

        err = clEnqueueWriteBuffer(commands, tb_output, CL_TRUE, 0, sizeof(int) * max_tb, h_tb_output, 0, NULL, &writeevent);
        if (err != CL_SUCCESS) {
            printf("Error: Failed to write to source array h_tb_output_input!\n");
            printf("Test failed\n");
            return EXIT_FAILURE;
        }
        clWaitForEvents(1, &writeevent); 

        // Set the arguments to our compute kernel
        err = 0;
        for (int i = 0; i < 11; i++) {                                                               
            err |= clSetKernelArg(kernel, i, sizeof(int), &cfg.sub_mat[i]);
        }
        err |= clSetKernelArg(kernel, 11, sizeof(int),   &cfg.gap_open);
        err |= clSetKernelArg(kernel, 12, sizeof(int),   &cfg.gap_extend);
        err |= clSetKernelArg(kernel, 13, sizeof(int),   &cfg.ydrop); 
        err |= clSetKernelArg(kernel, 14, sizeof(uint),  &align_fields);
        err |= clSetKernelArg(kernel, 15, sizeof(uint),  &ref_len);
        err |= clSetKernelArg(kernel, 16, sizeof(uint),  &query_len);
        err |= clSetKernelArg(kernel, 17, sizeof(ulong), &ref_offset);
        err |= clSetKernelArg(kernel, 18, sizeof(ulong), &query_offset);
        err |= clSetKernelArg(kernel, 19, sizeof(cl_mem),   &ref_seq); 
        err |= clSetKernelArg(kernel, 20, sizeof(cl_mem),   &query_seq);
        err |= clSetKernelArg(kernel, 21, sizeof(cl_mem),   &tile_output);
        err |= clSetKernelArg(kernel, 22, sizeof(cl_mem),   &tb_output); 

        if (err != CL_SUCCESS) {
            printf("Error: Failed to set kernel arguments! %d\n", err);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

        // Execute the kernel over the entire range of our 1d input data set
        // using the maximum number of work group items for this device
        err = clEnqueueTask(commands, kernel, 0, NULL, NULL);
        if (err) {
            printf("Error: Failed to execute kernel! %d\n", err);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

        // Read back the results from the device to verify the output
        clFinish(commands);

        err = 0;
        err |= clEnqueueReadBuffer( commands, tile_output, CL_TRUE, 0, sizeof(int) * 16, h_tile_output, 0, NULL, &readevent );

        err |= clEnqueueReadBuffer( commands, tb_output, CL_TRUE, 0, sizeof(int) * max_tb, h_tb_output, 0, NULL, &readevent );


        if (err != CL_SUCCESS) {
            printf("Error: Failed to read output array! %d\n", err);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

        clWaitForEvents(1, &readevent);
        // Check Results

        int score = h_tile_output[0];
        int ref_pos = h_tile_output[1];
        int query_pos = h_tile_output[2];
        int num_tb = h_tile_output[5]*16;

        printf("\nScore %d\n", score);
        printf("Ref max pos %d\n", ref_pos);
        printf("Query max pos %d\n", query_pos);

        char* ref_buf = (char*) malloc(16 * num_tb);
        char* query_buf = (char*) malloc(16 * num_tb);

        int tb_pos = 0;
        int rp = ref_pos;
        int qp = query_pos;

        for (int i = 0; i < num_tb; i++) {
            uint32_t tb_ptr = h_tb_output[i];
            for(int j = 0; j < 16; j++){
                int dir = ((tb_ptr >> (2*j)) & TB_MASK);
                switch(dir) {
                    case Z:
                        break;
                    case D: 
                        ref_buf[tb_pos] = ref[rp];
                        query_buf[tb_pos] = '-';
                        tb_pos++;
                        rp--;
                        break;
                    case I:
                        ref_buf[tb_pos] = '-';
                        query_buf[tb_pos] = query[qp];
                        tb_pos++;
                        qp--;
                        break;
                    case M:
                        ref_buf[tb_pos] = ref[rp];
                        query_buf[tb_pos] = query[qp];
                        tb_pos++;
                        rp--;
                        qp--;
                        break;
                }
            }
        }

        std::string aligned_reference_str (ref_buf, tb_pos);
        std::string aligned_query_str (query_buf, tb_pos);

        std::reverse(aligned_reference_str.begin(), aligned_reference_str.end());
        std::reverse(aligned_query_str.begin(), aligned_query_str.end());

        printf("%s\n%s\n", aligned_reference_str.c_str(), aligned_query_str.c_str());
    }
    infile.close();

    //--------------------------------------------------------------------------
    // Shutdown and cleanup
    //-------------------------------------------------------------------------- 
    clReleaseMemObject(ref_seq);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(commands);
    clReleaseContext(context);

}
