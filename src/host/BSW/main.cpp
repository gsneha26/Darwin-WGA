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

    // BSW
    int band_size;

    // Output
    std::string output_filename;
};

#if defined(SDX_PLATFORM) && !defined(TARGET_DEVICE)
#define STR_VALUE(arg)      #arg
#define GET_STRING(name) STR_VALUE(name)
#define TARGET_DEVICE GET_STRING(SDX_PLATFORM)
#endif

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

    if (argc != 3) {
        printf("Usage: %s xclbin batch_size\n", argv[0]);
        return EXIT_FAILURE;
    }

    char *xclbin = argv[1];
    int new_batch_size = std::atoi(argv[2]); 
    int batch_size = new_batch_size;

    if(new_batch_size %16 != 0){
        batch_size = ((int)(new_batch_size/16))*16 + 16;
    }

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
    kernel = clCreateKernel(program, "BSW_bank0", &err);
    if (!kernel || err != CL_SUCCESS) {
        printf("Error: Failed to create compute kernel!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    // Create structs to define memory bank mapping
    cl_mem_ext_ptr_t bank0_ext;

    bank0_ext.flags = XCL_MEM_DDR_BANK0;
    bank0_ext.obj = NULL;
    bank0_ext.param = 0;

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
    cfg.band_size       = cfg_file.Value("BSW_params", "band_size");

    //Output
    cfg.output_filename = (std::string) cfg_file.Value("Output", "output_filename");

    ///////////////////////////////////////////////////////////////////////////////////////
    std::string ref;
    std::string query;
    std::ifstream infile;

    infile.open (cfg.reference_filename);
    getline(infile, ref);
    infile.close();
    int ref_len = ref.length();

    infile.open (cfg.query_filename);
    getline(infile, query);
    infile.close();
    int query_len = query.length();

    char h_ref_seq_input[ref_len];
    char h_query_seq_input[query_len];

    int k = 0;
    for(k = 0; k < ref_len; k++){
        h_ref_seq_input[k] = ref[k];
    }
    for(k = 0; k < query_len; k++){
        h_query_seq_input[k] = query[k];
    }

    cl_mem ref_seq;          
    cl_mem query_seq;        
    cl_event wr_evnt;
    cl_event readevent;

    ref_seq = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * ref_len, &bank0_ext, NULL);
    if (!(ref_seq)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    query_seq = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * query_len, &bank0_ext, NULL);
    if (!(query_seq)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    err = clEnqueueWriteBuffer(commands, ref_seq, CL_TRUE, 0, sizeof(char) * ref_len, h_ref_seq_input, 0, NULL, &wr_evnt);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    clWaitForEvents(1, &wr_evnt); 

    err = clEnqueueWriteBuffer(commands, query_seq, CL_TRUE, 0, sizeof(char) * query_len, h_query_seq_input, 0, NULL, &wr_evnt);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    clWaitForEvents(1, &wr_evnt); 

    ////////////////////////////////////////////////////////////////////////////////////////////

    int num_batch_size = 4 * batch_size;

    int h_batch_id_input[num_batch_size];
    int h_batch_params_input[num_batch_size];
    int h_batch_tile_output[4*num_batch_size];

    cl_mem batch_id;         
    cl_mem batch_params;     
    cl_mem batch_tile_output;

    uint batch_align_fields = 0;

    int i=0;

    infile.open("parameters.txt");
    while(!infile.eof()){

        std::string param;
        h_batch_id_input[i*4] = i;
        h_batch_id_input[i*4+1] = 0;
        h_batch_id_input[i*4+2] = 0;
        h_batch_id_input[i*4+3] = 0;
        getline(infile, param, ' ' );
        h_batch_params_input[i*4+2] = stoi(param);
        getline(infile, param, ' ' );
        h_batch_params_input[i*4+3] = stoi(param);
        getline(infile, param, ' ' );
        h_batch_params_input[i*4] = stoi(param);
        getline(infile, param, ' ' );
        h_batch_params_input[i*4+1] = stoi(param);

        i++;
    }

    infile.close();

    if(new_batch_size%16 != 0){
        for(i = new_batch_size; i < batch_size; i++){
            h_batch_id_input[i*4] = i;
            h_batch_id_input[i*4+1] = 0;
            h_batch_id_input[i*4+2] = 0;
            h_batch_id_input[i*4+3] = 0;

            h_batch_params_input[i*4]   = h_batch_params_input[(i-new_batch_size)*4];
            h_batch_params_input[i*4+1] = h_batch_params_input[(i-new_batch_size)*4+1];
            h_batch_params_input[i*4+2] = h_batch_params_input[(i-new_batch_size)*4+2];
            h_batch_params_input[i*4+3] = h_batch_params_input[(i-new_batch_size)*4+3];

        }
    }

    for (i = 0; i < num_batch_size*4; i++) {
        h_batch_tile_output[i] = 33;
    }

    // Create the input and output arrays in device memory for our calculation
    batch_id = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(int) * num_batch_size, &bank0_ext, NULL);
    if (!(batch_id)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    err = clEnqueueWriteBuffer(commands, batch_id, CL_TRUE, 0, sizeof(int) * num_batch_size,  h_batch_id_input, 0, NULL, &wr_evnt);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }
    clWaitForEvents(1, &wr_evnt); 

    batch_params = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(int) * num_batch_size, &bank0_ext, NULL);
    if (!(batch_params)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    err = clEnqueueWriteBuffer(commands, batch_params, CL_TRUE, 0, sizeof(int) * num_batch_size, h_batch_params_input, 0, NULL, &wr_evnt);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }
    clWaitForEvents(1, &wr_evnt); 

    batch_tile_output = clCreateBuffer(context,  CL_MEM_READ_WRITE | CL_MEM_EXT_PTR_XILINX,  sizeof(int) * num_batch_size*4, &bank0_ext, NULL);
    if (!(batch_tile_output)) {
        printf("Error: Failed to allocate device memory!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }
    
    err = clEnqueueWriteBuffer(commands, batch_tile_output, CL_TRUE, 0, sizeof(int) * num_batch_size*4, h_batch_tile_output, 0, NULL, &wr_evnt);
    if (err != CL_SUCCESS) {
        printf("Error: Failed to write to source array h_ref_seq_input!\n");
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    clWaitForEvents(1, &wr_evnt); 

    err = 0;
    for (int i = 0; i < 11; i++) {                                                               
        err |= clSetKernelArg(kernel, i, sizeof(int), &cfg.sub_mat[i]);
    }
    err |= clSetKernelArg(kernel, 11, sizeof(int),   &cfg.gap_open);
    err |= clSetKernelArg(kernel, 12, sizeof(int),   &cfg.gap_extend);
    err |= clSetKernelArg(kernel, 13, sizeof(int),   &cfg.band_size); 
    err |= clSetKernelArg(kernel, 14, sizeof(uint),  &batch_size);
    err |= clSetKernelArg(kernel, 15, sizeof(uint),  &batch_align_fields);
    err |= clSetKernelArg(kernel, 16, sizeof(cl_mem), &ref_seq);
    err |= clSetKernelArg(kernel, 17, sizeof(cl_mem), &query_seq);
    err |= clSetKernelArg(kernel, 18, sizeof(cl_mem), &batch_id);
    err |= clSetKernelArg(kernel, 19, sizeof(cl_mem), &batch_params);
    err |= clSetKernelArg(kernel, 20, sizeof(cl_mem), &batch_tile_output);

    if (err != CL_SUCCESS) {
        printf("Error: Failed to set kernel arguments! %d\n", err);
        printf("Test failed\n");
        return EXIT_FAILURE;
    }

    err = clEnqueueTask(commands, kernel, 0, NULL, NULL);
    if (err) {
            printf("Error: Failed to execute kernel! %d\n", err);
            printf("Test failed\n");
            return EXIT_FAILURE;
        }

    clFinish(commands);

    err = 0;
    err |= clEnqueueReadBuffer( commands, batch_tile_output, CL_TRUE, 0, 4*sizeof(uint) * num_batch_size, h_batch_tile_output, 0, NULL, &readevent );

    if (err != CL_SUCCESS) {
        printf("error: failed to read output array! %d\n", err);
        printf("test failed\n");
        return EXIT_FAILURE;
    }

    clWaitForEvents(1, &readevent);

    for (uint i = 0; i < batch_size; i++) {
        int tile_id = h_batch_tile_output[i*16];
        int tile_score = h_batch_tile_output[i*16+2];
        int tile_ref = h_batch_tile_output[i*16+3];
        int tile_query = h_batch_tile_output[i*16+4];

        printf("%d, %d, %d, %d\n", tile_id, tile_score, tile_ref, tile_query);
    }

    //--------------------------------------------------------------------------
    // Shutdown and cleanup
    //-------------------------------------------------------------------------- 
    clReleaseMemObject(ref_seq);
    clReleaseProgram(program);
    clReleaseKernel(kernel);
    clReleaseCommandQueue(commands);
    clReleaseContext(context);

}
