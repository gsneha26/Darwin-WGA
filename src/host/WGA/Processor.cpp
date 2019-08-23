#include "Processor.h"
#include "graph.h"
#include <mutex>
#include <cstring>
#include "tbb/scalable_allocator.h"

#define NUM_KERNELS 4
#define NUM_BANKS 4
#define MAX_BANDED_TILE_SIZE 512
#define MAX_GACTX_TILE_SIZE 2048
#define MAX_GACTX_TB_BYTES MAX_GACTX_TILE_SIZE/2

std::mutex fpga_lock[NUM_KERNELS];
std::mutex gactx_lock;
std::mutex rw_lock;
std::atomic<int> num_executing[NUM_KERNELS];

const char A_NT = 0;
const char C_NT = 1;
const char G_NT = 2;
const char T_NT = 3;
const char N_NT = 4;

int err;                            // error code returned from api calls
int check_status = 0;

int start_op[NUM_KERNELS];

cl_platform_id platform_id;         // platform id
cl_device_id device_id;             // compute device id
cl_context context;                 // compute context
cl_command_queue commands[NUM_KERNELS];          // compute command queue
cl_program program;                 // compute programs
cl_kernel kernel[NUM_KERNELS];                   // compute kernel

cl_kernel gactx_kernel;
cl_command_queue gactx_commands; 

char cl_platform_vendor[1001];
char target_device_name[1001] = TARGET_DEVICE;

uint min_batch_size = 16;
uint num_ints_per_tile_in = 4;
uint num_ints_per_tile_out = 16;


// Create structs to define memory bank mapping
cl_mem_ext_ptr_t d_bank_ext[NUM_BANKS];

cl_mem d_ref_seq[NUM_BANKS];
cl_mem d_query_seq[NUM_BANKS];
cl_mem d_batch_id[NUM_BANKS];
cl_mem d_batch_params[NUM_BANKS];
cl_mem d_batch_tile_output[NUM_BANKS][4];

cl_mem d_gactx_tile_output;
cl_mem d_gactx_tb_output;

// Get all platforms and then select Xilinx platform
cl_platform_id platforms[16];       // platform id
cl_uint platform_count;
int platform_found = 0;


cl_uint num_devices;
unsigned int device_found = 0;
cl_device_id devices[16];  // compute device id
char cl_device_name[1001];

std::vector<int> available_k;

int status;

int Nt2Int(char nt, int complement)
{
	int ret = N_NT;

    switch (nt) {
        case 'a':
        case 'A': ret = (complement) ? T_NT : A_NT;
                  break;
        case 'c':
        case 'C': ret = (complement) ? G_NT : C_NT;
                  break;
        case 'g':
        case 'G': ret = (complement) ? C_NT : G_NT;
                  break;
        case 't':
        case 'T': ret = (complement) ? A_NT : T_NT;
                  break;
        case 'n':
        case 'N': ret = N_NT;
                  break;
        default:
                  break;
    }

    return ret;
}



int load_file_to_memory(const char *filename, char **result)
{
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

size_t InitializeProcessor (int t, int f, char* xclbin) {
    size_t ret = 0;

    fprintf(stderr, "XCLBIN is: %s\n", xclbin);

    err = clGetPlatformIDs(16, platforms, &platform_count);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to find an OpenCL platform!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    fprintf(stderr, "INFO: Found %d platforms\n", platform_count);

    // Find Xilinx Plaftorm
    for (unsigned int iplat=0; iplat<platform_count; iplat++) {
        err = clGetPlatformInfo(platforms[iplat], CL_PLATFORM_VENDOR, 1000, (void *)cl_platform_vendor,NULL);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: clGetPlatformInfo(CL_PLATFORM_VENDOR) failed!");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        if (strcmp(cl_platform_vendor, "Xilinx") == 0) {
            fprintf(stderr, "INFO: Selected platform %d from %s\n", iplat, cl_platform_vendor);
            platform_id = platforms[iplat];
            platform_found = 1;
        }
    }
    if (!platform_found) {
        fprintf(stderr, "ERROR: Platform Xilinx not found. Exit.\n");
        return EXIT_FAILURE;
    }

    // Get Accelerator compute device
    err = clGetDeviceIDs(platform_id, CL_DEVICE_TYPE_ACCELERATOR, 16, devices, &num_devices);
    fprintf(stderr, "INFO: Found %d devices\n", num_devices);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to create a device group!\n");
        fprintf(stderr, "ERROR: Test failed\n");
        return -1;
    }

    //iterate all devices to select the target device.
    for (uint i=0; i<num_devices; i++) {
        err = clGetDeviceInfo(devices[i], CL_DEVICE_NAME, 1024, cl_device_name, 0);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to get device name for device %d!\n", i);
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        fprintf(stderr, "CL_DEVICE_NAME %s\n", cl_device_name);
        if(strcmp(cl_device_name, target_device_name) == 0) {
            device_id = devices[i];
            device_found = 1;
            fprintf(stderr, "Selected %s as the target device\n", cl_device_name);
        }
    }

    if (!device_found) {
        fprintf(stderr, "Target device %s not found. Exit.\n", target_device_name);
        return EXIT_FAILURE;
    }

    // Create a compute context
    //
    context = clCreateContext(0, 1, &device_id, NULL, NULL, &err);
    if (!context) {
        fprintf(stderr, "Error: Failed to create a compute context!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }

    // Create a command commands
    for (int k = 0; k < NUM_KERNELS; k++) {
        commands[k] = clCreateCommandQueue(context, device_id, 0, &err);
        if (!commands[k]) {
            fprintf(stderr, "Error: Failed to create a command commands!\n");
            fprintf(stderr, "Error: code %i\n",err);
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
    }

    gactx_commands = clCreateCommandQueue(context, device_id, 0, &err);
    if (!gactx_commands) {
        fprintf(stderr, "Error: Failed to create a command commands!\n");
        fprintf(stderr, "Error: code %i\n",err);
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }

    // Create Program Objects
    // Load binary from disk
    unsigned char *kernelbinary;

    //------------------------------------------------------------------------------
    // xclbin
    //------------------------------------------------------------------------------
    fprintf(stderr, "INFO: loading xclbin %s\n", xclbin);
    int n_i0 = load_file_to_memory(xclbin, (char **) &kernelbinary);
    if (n_i0 < 0) {
        fprintf(stderr, "failed to load kernel from xclbin: %s\n", xclbin);
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }

    fprintf(stderr, "INFO: loaded xclbin %s\n", xclbin);
    size_t n0 = n_i0;

    fprintf(stderr, "Creating cl program with binary\n");
    // Create the compute program from offline
    program = clCreateProgramWithBinary(context, 1, &device_id, &n0,
            (const unsigned char **) &kernelbinary, &status, &err);

    if ((!program) || (err!=CL_SUCCESS)) {
        fprintf(stderr, "Error: Failed to create compute program from binary %d!\n", err);
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    fprintf(stderr, "Created cl program with binary\n");
    fprintf(stderr, "Building Program executable\n");

    // Build the program executable
    //
    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err != CL_SUCCESS) {
        size_t len;
        char buffer[2048];

        fprintf(stderr, "Error: Failed to build program executable!\n");
        clGetProgramBuildInfo(program, device_id, CL_PROGRAM_BUILD_LOG, sizeof(buffer), buffer, &len);
        fprintf(stderr, "%s\n", buffer);
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    fprintf(stderr, "Built Program executable\n");

    fprintf(stderr, "Creating kernels\n");

    // Create the compute kernel in the program we wish to run

    std::string s1 = "BSW_bank";
    std::string s;// = "BSW_bank";
    for (int k = 0; k < NUM_KERNELS; k++) {
        s = s1 + std::to_string(k);

        kernel[k] = clCreateKernel(program, s.c_str(), &err);
        if (!kernel[k] || err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to create compute kernel!\n");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
    }

    gactx_kernel = clCreateKernel(program, "GACTX_bank3", &err);
    if (!gactx_kernel || err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to create compute kernel!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }

    for (int k = 0; k < NUM_KERNELS; k++) {
        start_op[k] = 0;
        num_executing[k] = 0;
        available_k.push_back(k);
    }

    fprintf(stderr, "Created kernels\n");

    fprintf(stderr, "Creating buffers\n");

    // Create the input and output arrays in device memory for our calculation
    d_bank_ext[0].flags = XCL_MEM_DDR_BANK0;
    d_bank_ext[0].obj = NULL;
    d_bank_ext[0].param = 0;

    d_bank_ext[1].flags = XCL_MEM_DDR_BANK1;
    d_bank_ext[1].obj = NULL;
    d_bank_ext[1].param = 0;

    d_bank_ext[2].flags = XCL_MEM_DDR_BANK2;
    d_bank_ext[2].obj = NULL;
    d_bank_ext[2].param = 0;

    d_bank_ext[3].flags = XCL_MEM_DDR_BANK3;
    d_bank_ext[3].obj = NULL;
    d_bank_ext[3].param = 0;

    cl_event wr_event;
    cl_event rd_event;


    int max_size = MAX_NUM_TILES * std::max(num_ints_per_tile_in, num_ints_per_tile_out);
    max_size = std::max(max_size, MAX_GACTX_TB_BYTES/4);
    int* tmp_arr = (int*) calloc(max_size, sizeof(int)); 

    // Create the input and output arrays in device memory for our calculation

    for (int b = 0; b < NUM_KERNELS;  b++) {
        d_batch_id[b] = clCreateBuffer(context,  CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX ,  sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_in, &d_bank_ext[b], NULL);
        if (!(d_batch_id[b])) {
            fprintf(stderr, "Error: Failed to allocate device memory!\n");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        err = clEnqueueWriteBuffer(commands[b], d_batch_id[b], CL_TRUE, 0, sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_in,  tmp_arr, 0, NULL, &wr_event);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to write to source array d_batch_id_0!\n");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        clWaitForEvents(1, &wr_event); 

        d_batch_params[b] = clCreateBuffer(context,  CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX ,  sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_in, &d_bank_ext[b], NULL);
        if (!(d_batch_params[b])) {
            fprintf(stderr, "Error: Failed to allocate device memory!\n");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        err = clEnqueueWriteBuffer(commands[b], d_batch_params[b], CL_TRUE, 0, sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_in,  tmp_arr, 0, NULL, &wr_event);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to write to source array d_batch_params_0!\n");
            fprintf(stderr, "Test failed\n");
            return EXIT_FAILURE;
        }
        clWaitForEvents(1, &wr_event); 

        for (int j = 0; j < 4; j++) {
            d_batch_tile_output[b][j] = clCreateBuffer(context,  CL_MEM_WRITE_ONLY | CL_MEM_EXT_PTR_XILINX ,  sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_out, &d_bank_ext[b], NULL);
            if (!(d_batch_tile_output[b][j])) {
                fprintf(stderr, "Error: Failed to allocate device memory!\n");
                fprintf(stderr, "Test failed\n");
                return EXIT_FAILURE;
            }
            err = clEnqueueWriteBuffer(commands[b], d_batch_tile_output[b][j], CL_TRUE, 0, sizeof(int) * MAX_NUM_TILES * num_ints_per_tile_out,  tmp_arr, 0, NULL, &wr_event);
            if (err != CL_SUCCESS) {
                fprintf(stderr, "Error: Failed to write to source array d_batch_tile_output_0_0!\n");
                fprintf(stderr, "Test failed\n");
                return EXIT_FAILURE;
            }
            clWaitForEvents(1, &wr_event); 

        }
    }

    //GACTX buffers
    d_gactx_tile_output = clCreateBuffer(context,  CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX ,  sizeof(int) * 16, &d_bank_ext[3], NULL);
    if (!(d_gactx_tile_output)) {
        fprintf(stderr, "Error: Failed to allocate device memory!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    err = clEnqueueWriteBuffer(gactx_commands, d_gactx_tile_output, CL_TRUE, 0, sizeof(int) * 16,  tmp_arr, 0, NULL, &wr_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to write to source array d_batch_id_0!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    clWaitForEvents(1, &wr_event); 

    d_gactx_tb_output = clCreateBuffer(context,  CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX ,  MAX_GACTX_TB_BYTES, &d_bank_ext[3], NULL);
    if (!(d_gactx_tile_output)) {
        fprintf(stderr, "Error: Failed to allocate device memory!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    err = clEnqueueWriteBuffer(gactx_commands, d_gactx_tb_output, CL_TRUE, 0, MAX_GACTX_TB_BYTES,  tmp_arr, 0, NULL, &wr_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to write to source array d_batch_id_0!\n");
        fprintf(stderr, "Test failed\n");
        return EXIT_FAILURE;
    }
    clWaitForEvents(1, &wr_event); 

    free(tmp_arr);

    return ret;
}

void SendRefWriteRequest (size_t start_addr, size_t len) {

    cl_event writeevent;

    fprintf(stderr, "Sending reference to FPGA DRAM\n");

    for (int b = 0; b < NUM_KERNELS; b++) {
        d_ref_seq[b] = clCreateBuffer(context,   CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * len, &d_bank_ext[b], NULL);
        if (!(d_ref_seq[b])) {
            fprintf(stderr, "Error: Failed to allocate device memory!\n");
            fprintf(stderr, "Test failed\n");
            exit(1);
        }
        err = clEnqueueWriteBuffer(commands[b], d_ref_seq[b], CL_TRUE, 0, sizeof(char) * len, g_DRAM->buffer + start_addr, 0, NULL, &writeevent);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to write to source array!\n");
            fprintf(stderr, "Test failed\n");
            return;
        }
        clWaitForEvents(1, &writeevent); 
    }

}

void SendQueryWriteRequest (size_t start_addr, size_t len) {
    
    cl_event writeevent;
    
    fprintf(stderr, "Sending query to FPGA DRAM\n");

    for (int b = 0; b < NUM_KERNELS; b++) {
        d_query_seq[b] = clCreateBuffer(context,   CL_MEM_READ_ONLY | CL_MEM_EXT_PTR_XILINX,  sizeof(char) * len, &d_bank_ext[b], NULL);
        if (!(d_query_seq[b])) {
            fprintf(stderr, "Error: Failed to allocate device memory!\n");
            fprintf(stderr, "Test failed\n");
            exit(1);
        }
        err = clEnqueueWriteBuffer(commands[b], d_query_seq[b], CL_TRUE, 0, sizeof(char) * len, g_DRAM->buffer + start_addr, 0, NULL, &writeevent);
        if (err != CL_SUCCESS) {
            fprintf(stderr, "Error: Failed to write to source array!\n");
            fprintf(stderr, "Test failed\n");
            return;
        }
        clWaitForEvents(1, &writeevent); 
    }

}

void SendRequest (size_t ref_offset, size_t query_offset, size_t ref_length, size_t query_length, uint8_t align_fields) {

    if (!kernel[0]) {
        fprintf(stderr, "ERROR: kernel not initialized! Exiting.\n");
        exit(1);
    }
    
}

std::vector<tile_output> SendBatchRequest (std::vector<filter_tile> tiles, uint8_t align_fields, int thresh) {
    int err = 0;

    size_t num_tiles = tiles.size();
    size_t extra = num_tiles % 16; 
    if (extra != 0) {
        extra = 16 - extra;
    }
    size_t batch_size = (num_tiles + extra);

    int* h_batch_id;
    int* h_batch_params;
    int* h_batch_tile_output;

    h_batch_id = new int[4*batch_size];
    h_batch_params = new int[4*batch_size];
    h_batch_tile_output = new int[16*batch_size];

    for (int b = 0; b < batch_size; b++) {
        int idx = std::min(b,(int) num_tiles-1);
        filter_tile tile = tiles[idx];
        h_batch_id[4*b] = b;
        h_batch_id[4*b+1] = 0;
        h_batch_id[4*b+2] = 0;
        h_batch_id[4*b+3] = 0;
        h_batch_params[4*b] =   tile.ref_offset;
        h_batch_params[4*b+1] = tile.query_offset;
        h_batch_params[4*b+2] = tile.ref_length;
        h_batch_params[4*b+3] = tile.query_length;

        assert(tile.ref_length <= MAX_BANDED_TILE_SIZE);
        assert(tile.query_length <= MAX_BANDED_TILE_SIZE);
    }

    cl_event wr_event;
    cl_event rd_event;

    int curr_k = -1;
    int s_op = 0;

    while (curr_k < 0) {
        rw_lock.lock();
        int s = available_k.size();
        if (s > 0) {
            std::sort(available_k.begin(), available_k.end());
            std::reverse(available_k.begin(), available_k.end());
            curr_k = available_k.back();
            s_op = start_op[curr_k];
            start_op[curr_k] = (start_op[curr_k] + 1) % 4;
            available_k.pop_back();
        }
        rw_lock.unlock();
    }


    fpga_lock[curr_k].lock();
    
    while (num_executing[curr_k] == 4) {}
    num_executing[curr_k] += 1;

    err = clEnqueueWriteBuffer(commands[curr_k], d_batch_id[curr_k], CL_TRUE, 0, sizeof(int) * batch_size * num_ints_per_tile_in,  h_batch_id, 0, NULL, &wr_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to write to source array !\n");
        fprintf(stderr, "Test failed\n");
        exit(1);
    }
    clWaitForEvents(1, &wr_event); 


    err = clEnqueueWriteBuffer(commands[curr_k], d_batch_params[curr_k], CL_TRUE, 0, sizeof(int) * batch_size * num_ints_per_tile_in,  h_batch_params, 0, NULL, &wr_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to write to source array !\n");
        fprintf(stderr, "Test failed\n");
        exit(1);
    }
    clWaitForEvents(1, &wr_event); 

    err = 0;
    for (int i = 0; i < 11; i++) {
        err |= clSetKernelArg(kernel[curr_k], i, sizeof(int), &cfg.gact_sub_mat[i]);
    }
    err |= clSetKernelArg(kernel[curr_k], 11, sizeof(int), &cfg.gap_open);
    err |= clSetKernelArg(kernel[curr_k], 12, sizeof(int), &cfg.gap_extend);
    uint d_band_size = cfg.band_size;
    err |= clSetKernelArg(kernel[curr_k], 13, sizeof(uint), &d_band_size);
    uint d_batch_size = batch_size;
    err |= clSetKernelArg(kernel[curr_k], 14, sizeof(uint), &d_batch_size);
    uint d_batch_align_fields = align_fields;
    err |= clSetKernelArg(kernel[curr_k], 15, sizeof(uint), &d_batch_align_fields);
    err |= clSetKernelArg(kernel[curr_k], 16, sizeof(cl_mem), &d_ref_seq[curr_k]);
    err |= clSetKernelArg(kernel[curr_k], 17, sizeof(cl_mem), &d_query_seq[curr_k]);
    err |= clSetKernelArg(kernel[curr_k], 18, sizeof(cl_mem), &d_batch_id[curr_k]);
    err |= clSetKernelArg(kernel[curr_k], 19, sizeof(cl_mem), &d_batch_params[curr_k]);
    err |= clSetKernelArg(kernel[curr_k], 20, sizeof(cl_mem), &d_batch_tile_output[curr_k][s_op % 4]);

    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to set kernel arguments! %d\n", err);
        fprintf(stderr, "Test failed\n");
        exit(1);
    }

    // Execute the kernel over the entire range of our 1d input data set
    // using the maximum number of work group items for this device

    err = clEnqueueTask(commands[curr_k], kernel[curr_k], 0, NULL, NULL);
    if (err) {
        fprintf(stderr, "Error: Failed to execute kernel! %d\n", err);
        fprintf(stderr, "Test failed\n");
        exit(1);
    }

    // Read back the results from the device to verify the output
    clFinish(commands[curr_k]);

    fpga_lock[curr_k].unlock();

    err = 0;
    err |= clEnqueueReadBuffer(commands[curr_k], d_batch_tile_output[curr_k][s_op % 4], CL_TRUE, 0, sizeof(int) * batch_size * num_ints_per_tile_out, h_batch_tile_output, 0, NULL, &rd_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "error: failed to read output array! %d\n", err);
        fprintf(stderr, "test failed\n");
        exit(1);
    }
    clWaitForEvents(1, &rd_event);

    num_executing[curr_k] -= 1;

    rw_lock.lock();
    available_k.push_back(curr_k);
    rw_lock.unlock();

    std::vector <tile_output> filtered_op;
    filtered_op.clear();

    for (int b = 0; b < batch_size; b++) {
        ushort tile_id;
        int tile_score;
        uint32_t ro, qo;
        tile_id     = h_batch_tile_output[b*16];
        if (tile_id < num_tiles) {
            tile_score  = h_batch_tile_output[b*16+2];
            ro          = h_batch_tile_output[b*16+3];
            qo          = h_batch_tile_output[b*16+4];
            if (tile_score >= thresh) {
                tile_output op = tile_output(tile_id, tile_score, ro, qo);
                filtered_op.push_back(op);
            }
        }
    }

    free(h_batch_id);
    free(h_batch_params);
    free(h_batch_tile_output);

    return filtered_op;
}

extend_output GACTXRequest (extend_tile tile, uint8_t align_fields) {
    extend_output op;
    int err = 0;
    int h_gactx_tile_output[16];
    uint32_t h_gactx_tb_output[MAX_GACTX_TB_BYTES/4];
    
    assert(tile.ref_length <= MAX_GACTX_TILE_SIZE);
    assert(tile.query_length <= MAX_GACTX_TILE_SIZE);

    gactx_lock.lock();

    for (int i = 0; i < 11; i++) {
        err |= clSetKernelArg(gactx_kernel, i, sizeof(int), &cfg.gact_sub_mat[i]);
    }
    err |= clSetKernelArg(gactx_kernel, 11, sizeof(int), &cfg.gap_open);
    err |= clSetKernelArg(gactx_kernel, 12, sizeof(int), &cfg.gap_extend);
    uint d_y_drop = cfg.ydrop;
    err |= clSetKernelArg(gactx_kernel, 13, sizeof(uint), &d_y_drop);
    uint32_t d_batch_align_fields = align_fields;
    err |= clSetKernelArg(gactx_kernel, 14, sizeof(uint), &d_batch_align_fields);
    uint32_t d_ref_len = tile.ref_length;
    err |= clSetKernelArg(gactx_kernel, 15, sizeof(cl_uint), &d_ref_len);
    uint32_t d_query_len = tile.query_length;
    err |= clSetKernelArg(gactx_kernel, 16, sizeof(cl_uint), &d_query_len);
    uint64_t d_ref_offset = tile.ref_offset;
    err |= clSetKernelArg(gactx_kernel, 17, sizeof(cl_ulong), &d_ref_offset);
    uint64_t d_query_offset = tile.query_offset;
    err |= clSetKernelArg(gactx_kernel, 18, sizeof(cl_ulong), &d_query_offset);
    err |= clSetKernelArg(gactx_kernel, 19, sizeof(cl_mem), &d_ref_seq[3]);
    err |= clSetKernelArg(gactx_kernel, 20, sizeof(cl_mem), &d_query_seq[3]);
    err |= clSetKernelArg(gactx_kernel, 21, sizeof(cl_mem), &d_gactx_tile_output);
    err |= clSetKernelArg(gactx_kernel, 22, sizeof(cl_mem), &d_gactx_tb_output);


    if (err != CL_SUCCESS) {
        fprintf(stderr, "Error: Failed to set kernel arguments! %d\n", err);
        fprintf(stderr, "Test failed\n");
        exit(1);
    }

    err = clEnqueueTask(gactx_commands, gactx_kernel, 0, NULL, NULL);
    if (err) {
        fprintf(stderr, "Error: Failed to execute kernel! %d\n", err);
        fprintf(stderr, "Test failed\n");
        exit(1);
    }

    clFinish(gactx_commands);

    cl_event rd_event;
    
    err = 0;
    err |= clEnqueueReadBuffer(gactx_commands, d_gactx_tile_output, CL_TRUE, 0, sizeof(int) * 16, h_gactx_tile_output, 0, NULL, &rd_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "error: failed to read output array! %d\n", err);
        fprintf(stderr, "test failed\n");
        exit(1);
    }
    clWaitForEvents(1, &rd_event);

    err = 0;
    err |= clEnqueueReadBuffer(gactx_commands, d_gactx_tb_output, CL_TRUE, 0, sizeof(int) * MAX_GACTX_TB_BYTES/4, h_gactx_tb_output, 0, NULL, &rd_event);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "error: failed to read output array! %d\n", err);
        fprintf(stderr, "test failed\n");
        exit(1);
    }
    clWaitForEvents(1, &rd_event);

    gactx_lock.unlock();

    int score = h_gactx_tile_output[0];
    op.max_ref_offset = h_gactx_tile_output[1];
    op.max_query_offset = h_gactx_tile_output[2];
    int num_tb = 16 * h_gactx_tile_output[5];
    
    op.tb_pointers.clear();
    for (int i=0; i < num_tb; i++) {
        op.tb_pointers.push_back(h_gactx_tb_output[i]);
    }

    return op;
}

void ShutdownProcessor() {
    for (int i = 0; i < NUM_KERNELS; i++) {
        clReleaseMemObject(d_ref_seq[i]);
        clReleaseMemObject(d_query_seq[i]);
        clReleaseMemObject(d_batch_id[i]);
        clReleaseMemObject(d_batch_params[i]);
        for (int j = 0; j < 4; j++) {
            clReleaseMemObject(d_batch_tile_output[i][j]);
        }
    }

    clReleaseProgram(program);
    for (int k = 0; k < NUM_KERNELS; k++){
        clReleaseKernel(kernel[k]);
        clReleaseCommandQueue(commands[k]);
    }
    clReleaseMemObject(d_gactx_tile_output);
    clReleaseMemObject(d_gactx_tb_output);
    clReleaseCommandQueue(gactx_commands);
    clReleaseKernel(gactx_kernel);
    clReleaseContext(context);
}

DRAM *g_DRAM = nullptr;

InitializeProcessor_ptr g_InitializeProcessor = InitializeProcessor;
ShutdownProcessor_ptr g_ShutdownProcessor = ShutdownProcessor;
SendRequest_ptr g_SendRequest = SendRequest;
SendBatchRequest_ptr g_SendBatchRequest = SendBatchRequest;
GACTXRequest_ptr g_GACTXRequest = GACTXRequest;
SendRefWriteRequest_ptr g_SendRefWriteRequest = SendRefWriteRequest;
SendQueryWriteRequest_ptr g_SendQueryWriteRequest = SendQueryWriteRequest;
