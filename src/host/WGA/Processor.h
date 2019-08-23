#pragma once

#include "DRAM.h"
#include <vector>
#include <string.h>
#include <stdio.h>
#include <mutex>
#include <CL/opencl.h>
#include <CL/cl_ext.h>

#define NUM_WORKGROUPS (1)
#define WORKGROUP_SIZE (256)
#define MAX_LENGTH 8192
#define NUM_BATCH_PER_BEAT 4
#define NUM_CHAR_PER_BEAT 64

#if defined(SDX_PLATFORM) && !defined(TARGET_DEVICE)
#define STR_VALUE(arg)      #arg
#define GET_STRING(name) STR_VALUE(name)
#define TARGET_DEVICE GET_STRING(SDX_PLATFORM)
#endif


#define INF (1 << 28)
#define MAX_TILE_SIZE 512

#define MAX_NUM_TILES (1 << 20)
    
typedef int AlnOp;
enum AlnOperands { ZERO_OP, INSERT_OP, DELETE_OP, LONG_INSERT_OP, LONG_DELETE_OP};
enum states { Z, I, D, M , L_Z, L_I, L_D};

struct filter_tile 
{
    filter_tile (size_t ro, size_t qo, size_t rl, size_t ql, size_t qs) 
        : ref_offset(ro),
          query_offset(qo),
          ref_length(rl),
          query_length(ql),
          query_tile_start(qs)
    {};
    size_t ref_offset;
    size_t query_offset;
    size_t ref_length;
    size_t query_length;
    size_t query_tile_start;
};

struct tile_output {
    tile_output (int id, int s, uint32_t ro, uint32_t qo) 
      : batch_id(id),
        tile_score(s),
        max_ref_offset(ro),
        max_query_offset(qo)
    {};
    int batch_id;
    int tile_score;
    uint32_t max_ref_offset;
    uint32_t max_query_offset;

};

struct extend_tile 
{
    extend_tile (size_t ro, size_t qo, size_t rl, size_t ql) 
        : ref_offset(ro),
          query_offset(qo),
          ref_length(rl),
          query_length(ql)
    {};
    size_t ref_offset;
    size_t query_offset;
    size_t ref_length;
    size_t query_length;
};

struct extend_output {
    uint32_t max_ref_offset;
    uint32_t max_query_offset;
    std::vector<uint32_t> tb_pointers;

};

typedef size_t(*InitializeProcessor_ptr)(int t, int f, char* xclbin);
typedef void(*SendRequest_ptr)(size_t ref_offset, size_t query_offset, size_t ref_length, size_t query_length, uint8_t align_fields);
typedef std::vector<tile_output> (*SendBatchRequest_ptr)(std::vector<filter_tile> tiles, uint8_t align_fields, int thresh);
typedef extend_output (*GACTXRequest_ptr)(extend_tile tile, uint8_t align_fields);
typedef void(*ShutdownProcessor_ptr)();
typedef void(*SendRefWriteRequest_ptr)(size_t addr, size_t len);
typedef void(*SendQueryWriteRequest_ptr)(size_t addr, size_t len);

extern DRAM *g_DRAM;
    
extern InitializeProcessor_ptr g_InitializeProcessor;
extern SendRequest_ptr g_SendRequest;
extern SendBatchRequest_ptr g_SendBatchRequest;
extern GACTXRequest_ptr g_GACTXRequest;
extern SendRefWriteRequest_ptr g_SendRefWriteRequest;
extern SendQueryWriteRequest_ptr g_SendQueryWriteRequest;
extern ShutdownProcessor_ptr g_ShutdownProcessor;
