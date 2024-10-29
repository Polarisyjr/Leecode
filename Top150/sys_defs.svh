/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file defines macros and data structures used   //
//                 throughout the processor.                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

`define DEBUG 0 

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define SUPERSCALAR_WAYS 3
`define SUPERSCALAR_IDX_WIDTH $clog2(`SUPERSCALAR_WAYS) 
`define N `SUPERSCALAR_WAYS 
`define CDB_SZ `N // This MUST match your superscalar width

typedef logic [`SUPERSCALAR_WAYS-1:0] ENABLE_MASK; 
typedef logic [`SUPERSCALAR_IDX_WIDTH:0] ENABLE_CNT; 

// sizes
`define ROB_SZ 32 // xx
`define RS_SZ  32 // xx
`define PHYS_REG_SZ_P6 32
`define PHYS_REG_SZ_R10K (32 + `ROB_SZ)

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ xx

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU 4 // xx
`define NUM_FU_MULT 2 // xx
`define NUM_FU_LOAD 2 // xx
`define NUM_FU_STORE 2 //xx

// number of mult stages (2, 4) (you likely don't need 8)
`define MULT_STAGES 4


///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
// TODO: uncomment this line once you've implemented your cache
//`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
//`define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// memory tags represent a unique id for outstanding mem transactions
// 0 is a sentinel value and is not a valid tag
`define NUM_MEM_TAGS 15
typedef logic [3:0] MEM_TAG;

`define MEM_BLOCK_SIZE 64 

`define BYTE_ADDR_BITS 3 // 3 bits are useless because we are byte addressable 
`define PC_ADDR_BITS 2
// btb definitions 
`define BTB_INST_PC_IDX_WIDTH  8 // how many bits are taken as index 
`define BTB_INST_PC_TAG_WIDTH  8 // how many bits are taken as tag 
`define BTB_DST_PARTIAL_PC_WIDTH 12     // how many bits in inst pc are replaced

// dirp 
`define BHR_WIDTH 8 // record how many bits of history  
`define DIRP_COUNTER_BITS 2 // 2 bit saturating counters 
`define DIRP_PHT_ENTRY_NUM (1<<`BHR_WIDTH) 
// dirp  
typedef logic[`BHR_WIDTH-1:0] BHR_ENTRY;  
typedef logic[`DIRP_COUNTER_BITS-1:0] DIRP_COUNTER; 
typedef DIRP_COUNTER [`DIRP_PHT_ENTRY_NUM-1:0] DIRP_PHT; 
function automatic DIRP_COUNTER DIRP_COUNTER_NULL(); 
    // initialize all counters to weakly not taken (0111....111) 
    DIRP_COUNTER counter;
    counter = {1'b0, {(`DIRP_COUNTER_BITS-1){1'b1}}};
    return counter;  
endfunction 


// total PHT size: 2^BHR_WIDTH entries, each entry is DIRP_COUNTER_BITS large  

// icache definitions 
`define ICACHE_LINE_WIDTH `MEM_BLOCK_SIZE 
`define ICACHE_LINES 32
`define ICACHE_LINE_BITS $clog2(`ICACHE_LINES)
`define ICACHE_SIZE  `ICACHE_LINE_WIDTH*`ICACHE_LINES
`define ICACHE_SET_IDX_BITS $clog2(`ICACHE_LINES) 

// dcache definitions (direct mapped) 
`define DCACHE_LINE_WIDTH `MEM_BLOCK_SIZE 
`define DCACHE_LINES 32
`define DCACHE_LINE_BITS $clog2(`DCACHE_LINES)
`define DCACHE_SIZE  `DCACHE_LINE_WIDTH*`DCACHE_LINES
`define DCACHE_SET_IDX_BITS $clog2(`DCACHE_LINES) 

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)
`define MEM_VALID_ADDR_BITS $clog2(`MEM_SIZE_IN_BYTES) 

`define BRANCH_CORRECTNESS_BUFFER_WIDTH 10

// fixed: icache and dcache are fixed to 32 lines + 64 bit blocks 
typedef  logic [`ICACHE_SET_IDX_BITS-1:0] CACHE_IDX;  
// typedef  logic [`MEM_VALID_ADDR_BITS-`ICACHE_SET_IDX_BITS-`BYTE_ADDR_BITS-1:0] CACHE_TAG; 
typedef  logic [32-`ICACHE_SET_IDX_BITS-`BYTE_ADDR_BITS-1:0] CACHE_TAG; 

typedef struct packed {
    CACHE_TAG tag; 
    logic valid; 
} CACHE_TAG_STRUCT;     // don't use ICACHE_TAGS 
`ifndef SYNTH
    function automatic void print_cache_tag_struct(input CACHE_TAG_STRUCT tag); 
        $display("----------------cache tag struct--------------------"); 
        $display("valid: %b tag: %h", tag.valid, tag.tag); 
        $display("----------------------------------------------------"); 
    endfunction
`endif 

typedef struct packed {
    CACHE_TAG tag; 
    CACHE_IDX idx; 
} MEM_BLOCK_IDX_AND_TAG;

typedef union packed {
    MEM_BLOCK_IDX_AND_TAG idx_and_tag; 
    // logic [`MEM_VALID_ADDR_BITS-`BYTE_ADDR_BITS-1:0] addr; 
    logic [32-`BYTE_ADDR_BITS-1:0] addr;  
} MEM_BLOCK_ADDR; 

// word and register sizes
typedef struct packed {
    // logic [32-`MEM_VALID_ADDR_BITS-1:0] other; 
    MEM_BLOCK_ADDR block_addr; 
    logic [`BYTE_ADDR_BITS-1:0] reserved; 
} CACHE_BLOCK_ADDR;

typedef struct packed{
    logic [32-`BHR_WIDTH-`PC_ADDR_BITS-1:0] other; 
    logic [`BHR_WIDTH-1:0]      bhr_pc; 
    logic [`PC_ADDR_BITS-1:0] reserved;  
} BHR_PC_BITS; 

typedef struct packed {
    logic [32-`BTB_INST_PC_TAG_WIDTH-`BTB_INST_PC_IDX_WIDTH-`PC_ADDR_BITS-1:0] other;  
    logic [`BTB_INST_PC_TAG_WIDTH-1:0] tag; 
    logic [`BTB_INST_PC_IDX_WIDTH-1:0] idx; 
    logic [`PC_ADDR_BITS-1:0] reserved; // first 3 bits are useless 
} BTB_SRC_ADDR;


typedef struct packed {
    logic [32-`BTB_DST_PARTIAL_PC_WIDTH-`PC_ADDR_BITS-1:0] other; 
    logic [`BTB_DST_PARTIAL_PC_WIDTH-1:0] partial_pc; 
    logic [`PC_ADDR_BITS-1:0] reserved; // first 3 bits are useless 
} BTB_DST_ADDR;

typedef struct packed {
    logic [32-`MEM_VALID_ADDR_BITS-1:0] other; 
    logic [`MEM_VALID_ADDR_BITS-`ICACHE_SET_IDX_BITS-`BYTE_ADDR_BITS-1:0] tag; 
    logic [`ICACHE_SET_IDX_BITS-1:0] set_idx; 
    logic [`BYTE_ADDR_BITS-1:0] reserved; // first 3 bits are useless 
} ICACHE_ADDR;

// LDRS for icache non blocking logic
`define ICACHE_LDRS_NUM 15 // same as number of valid memory transaction tags 
typedef struct packed {
    logic valid; 
    MEM_BLOCK_ADDR block_addr; // block address for this access 
    MEM_TAG        mem_tx_tag; // transaction tag for the issued memory access, will be filled when this entry is issued 
    logic issued; 
} ICACHE_LDRS_ENTRY; 

typedef struct packed {
    logic [32-`MEM_VALID_ADDR_BITS-1:0] other; 
    logic [`MEM_VALID_ADDR_BITS-`DCACHE_SET_IDX_BITS-`BYTE_ADDR_BITS-1:0] tag; 
    logic [`DCACHE_SET_IDX_BITS-1:0] set_idx; 
    logic [`BYTE_ADDR_BITS-1:0] reserved; // first 3 bits are useless 
} DCACHE_ADDR;

typedef union packed {
    CACHE_BLOCK_ADDR cache_block_addr; 
    BHR_PC_BITS  bhr_addr; 
    BTB_DST_ADDR btb_dst_addr; 
    BTB_SRC_ADDR btb_src_addr; 
    DCACHE_ADDR  dcache_addr; 
    ICACHE_ADDR  icache_addr; 
    logic [31:0] addr; 
} ADDR; 


// typedef logic [31:0] ADDR;
// typedef logic [31:0] DATA;
typedef union packed {
    logic [1:0][15:0] half_level; 
    logic [3:0][7:0] byte_level; 
    logic [31:0] bit_level;  
} DATA; 

typedef logic [63:0] MULT_OPERAND; 
typedef logic [4:0] REG_IDX;

// A memory or cache block
typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
    logic      [63:0] dbbl_level;
} MEM_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    MEM_NONE   = 2'h0,
    MEM_LOAD   = 2'h1,
    MEM_STORE  = 2'h2
} MEM_COMMAND;

// icache tag struct
typedef struct packed {
    logic [12-`ICACHE_LINE_BITS:0] tags;
    logic                          valid;
} ICACHE_TAG;

`ifndef SYNTH
    function automatic void print_icache_tag(input ICACHE_TAG icache_tag); 
        $display("tags: %h valid: %b",icache_tag.tags, icache_tag.valid ); 
    endfunction
`endif 
///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code
typedef enum logic [3:0] {
    ALU_ADD     = 4'h0,
    ALU_SUB     = 4'h1,
    ALU_SLT     = 4'h2,
    ALU_SLTU    = 4'h3,
    ALU_AND     = 4'h4,
    ALU_OR      = 4'h5,
    ALU_XOR     = 4'h6,
    ALU_SLL     = 4'h7,
    ALU_SRL     = 4'h8,
    ALU_SRA     = 4'h9
} ALU_FUNC;

// MULT funct3 code
// we don't include division or rem options
typedef enum logic [2:0] {
    M_MUL,
    M_MULH,
    M_MULHSU,
    M_MULHU
} MULT_FUNC;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST  inst; 
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;

    
    // INST [`SUPERSCALAR_WAYS-1:0] insts; // multiple instructions 
    // logic [`SUPERSCALAR_WAYS-1:0] fetch_valid; // indicate if each instruction is valid 
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST inst;
    ADDR PC;
    ADDR NPC; // PC + 4

    DATA rs1_value; // reg A value
    DATA rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    REG_IDX  dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC alu_func;      // ALU function select (ALU_xxx *)
    logic    mult;          // Is inst a multiply instruction?
    logic    rd_mem;        // Does inst read memory?
    logic    wr_mem;        // Does inst write memory?
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
    logic    halt;          // Is this a halt?
    logic    illegal;       // Is this instruction illegal?
    logic    csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic    valid;
} ID_EX_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    DATA alu_result;
    ADDR NPC;

    logic    take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    DATA     rs2_value;
    logic    rd_mem;
    logic    wr_mem;
    REG_IDX  dest_reg_idx;
    logic    halt;
    logic    illegal;
    logic    csr_op;
    logic    rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE mem_size;
    logic    valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    DATA    result;
    ADDR    NPC;
    REG_IDX dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic   take_branch;
    logic   halt;    // not used by wb stage
    logic   illegal; // not used by wb stage
    logic   valid;
} MEM_WB_PACKET;

/**
 * Commit Packet:
 * This is an output of the processor and used in the testbench for counting
 * committed instructions
 *
 * It also acts as a "WB_PACKET", and can be reused in the final project with
 * some slight changes
 */
typedef struct packed {
    ADDR    NPC;
    DATA    data;
    REG_IDX reg_idx;
    logic   halt;
    logic   illegal;
    logic   valid;
} COMMIT_PACKET;


// Custom definitions 
typedef enum logic [1:0] { 
    NORMAL, 
    SERIAL_ROLLBACK, 
    CKPT_ROLLBACK 
} PROCESSOR_STATE; 

// ------------------------- Custom Definitions ---------------------------  
// preg and areg 
`define PREG_NUM `PHYS_REG_SZ_R10K 
`define PREG_IDX_WIDTH $clog2(`PREG_NUM) 
`define AREG_NUM `PHYS_REG_SZ_P6 
`define AREG_IDX_WIDTH $clog2(`AREG_NUM) 
typedef logic[`PREG_IDX_WIDTH-1:0] PREG_IDX; 
typedef logic[`AREG_IDX_WIDTH-1:0] AREG_IDX; 


// FU related 
`define ALU_NUM 4 
`define MULT_NUM 2
`define BR_NUM 1 // don't change this!!!
`define STORE_NUM 1
`define LOAD_NUM 2
`define FU_NUM_TOTAL `ALU_NUM+`MULT_NUM+`BR_NUM+`STORE_NUM+`LOAD_NUM 

typedef logic[`ALU_NUM-1:0] FU_MASK_ALU;      // ALU functional unit mask
typedef logic[`MULT_NUM-1:0] FU_MASK_MULT;    // Multiplier functional unit mask
typedef logic[`BR_NUM-1:0] FU_MASK_BR;        // Branch functional unit mask
typedef logic[`STORE_NUM-1:0] FU_MASK_STORE;  // Store functional unit mask
typedef logic[`LOAD_NUM-1:0] FU_MASK_LOAD;    // Load functional unit mask

// bmask register
`define BMASK_WIDTH 4 
typedef logic [`BMASK_WIDTH-1:0] BMASK; 
typedef logic [`BMASK_WIDTH-1:0] BRANCH_TAG; 

typedef enum logic [2:0] { 
    FU_TAG_ALU, 
    FU_TAG_LOAD, 
    FU_TAG_STORE, 
    FU_TAG_MULT, 
    FU_TAG_BR 
} FU_TAG; 

typedef struct packed {
    logic is_cond_branch; 
    logic is_jump; 
    logic is_branch; 
} PREDECODER_PACKET;

// new packets 
// will be the packet from fetch stage 
typedef struct packed {
    INST  inst; 
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;  
        // bp related 
    BHR_ENTRY prev_bhr; 
    logic     predict_taken; 
} FETCH_PACKET; 

function automatic FETCH_PACKET FETCH_PACKET_NULL();
    FETCH_PACKET packet;
    packet = 0; 
    packet.inst = `NOP;       // Assuming `NOP` is defined as needed
    packet.valid = `FALSE;    // Assuming `FALSE` is defined as needed
    packet.NPC = 0;
    packet.PC = 0;
    return packet;
endfunction

`ifndef SYNTH 
    function automatic void print_fetch_packet(input FETCH_PACKET fetch_packet);  
        $display("-----------fetch packet----------"); 
        $display("valid: %b", fetch_packet.valid);  
        $display("inst: %h", fetch_packet.inst); 
        print_instr_name(fetch_packet.inst); 
        $display("PC: %h NPC: %h", fetch_packet.PC, fetch_packet.NPC); 
        $display("prev_bhr: %b", fetch_packet.prev_bhr);
        $display("predict_taken: %b", fetch_packet.predict_taken); 
        $display("---------------------------------"); 
    endfunction
`endif 


typedef struct packed {
    FETCH_PACKET [`SUPERSCALAR_WAYS-1:0] fetch_packets_reg; // indicates the packets 
    ENABLE_MASK  fetch_enable_reg; // indicates who were enabled on fetch  
    ENABLE_CNT   fetch_cnt; 
} FETCH_STAGE_REG; 

// this is the output of decoder 

typedef struct packed {
    logic          valid; 
    ALU_OPA_SELECT opa_select;
    ALU_OPB_SELECT opb_select;
    logic          has_dest; // if there is a destination register
    
    AREG_IDX       dest_reg_idx;
    AREG_IDX       reg1_idx;
    AREG_IDX       reg2_idx; 

    ALU_FUNC       alu_func; 
    logic          mult; 
    logic          rd_mem;
    logic          wr_mem;
    logic          cond_branch; 
    logic          uncond_branch;
    logic          is_branch; // is a branch, no matter conditional or unconditional  
    logic          csr_op; // used for CSR operations, we only use this as a cheap way to get the return code out
    logic          halt;   // non-zero on a halt
    logic          illegal; // non-zero on an illegal instruction
    FU_TAG         fu_tag; 

    FETCH_PACKET   fetch_packet;
} DECODER_PACKET;

function automatic DECODER_PACKET DECODER_PACKET_NULL();
    DECODER_PACKET packet;
    packet = 0; 
    packet.valid = `FALSE; 
    packet.opa_select = OPA_IS_RS1;
    packet.opb_select = OPB_IS_RS2;
    packet.has_dest =  `FALSE;
    packet.alu_func = ALU_ADD;
    packet.mult = `FALSE;
    packet.rd_mem = `FALSE;
    packet.wr_mem = `FALSE;
    packet.cond_branch = `FALSE;
    packet.uncond_branch = `FALSE;
    packet.is_branch    = `FALSE; 
    packet.csr_op = `FALSE;
    packet.halt = `FALSE;
    packet.illegal = `FALSE;
    packet.fu_tag = FU_TAG_ALU;
    return packet;
endfunction

function automatic DECODER_PACKET DECODER_PACKET_NOP(input DECODER_PACKET input_packet);  
    DECODER_PACKET packet; 
    packet = input_packet; 
    packet.fetch_packet.inst = `NOP; 
    packet.opa_select = OPA_IS_RS1; 
    packet.opb_select = OPB_IS_I_IMM; 
    packet.has_dest = 1; 
    packet.illegal = 0; 
    return packet; 
endfunction 

`ifndef SYNTH 
    function automatic void print_decoder_packet(input DECODER_PACKET decoder_packet);
        $display("-----------decoder packet----------");
        $display("valid: %d", decoder_packet.valid);
        // $display("opa_select: %s", decoder_packet.opa_select.name());
        // $display("opb_select: %s", decoder_packet.opb_select.name());
        $display("has_dest: %d", decoder_packet.has_dest);
        $display("dest_reg_idx: %d", decoder_packet.dest_reg_idx);
        $display("reg1_idx: %d", decoder_packet.reg1_idx);
        $display("reg2_idx: %d", decoder_packet.reg2_idx);
        // $display("alu_func: %s", decoder_packet.alu_func.name()); // Assuming ALU_FUNC is a simple numeric value
        $display("mult: %d", decoder_packet.mult);
        $display("rd_mem: %d", decoder_packet.rd_mem);
        $display("wr_mem: %d", decoder_packet.wr_mem);
        $display("cond_branch: %d", decoder_packet.cond_branch);
        $display("uncond_branch: %d", decoder_packet.uncond_branch);
        $display("is_branch: %d", decoder_packet.is_branch);
        $display("csr_op: %d", decoder_packet.csr_op);
        $display("halt: %d", decoder_packet.halt);
        $display("illegal: %d", decoder_packet.illegal);
        // $display("fu_tag: %s", decoder_packet.fu_tag.name());
        // Call the function to print the fetch packet
        print_fetch_packet(decoder_packet.fetch_packet);
        $display("---------------------------------");
    endfunction
`endif 

typedef struct packed {
    DECODER_PACKET [`SUPERSCALAR_WAYS-1:0] decode_packets_reg ; // indicates the packets 
    ENABLE_MASK  decode_enable_reg; // indicates who were enabled on fetch, passed through from fetch  
    ENABLE_CNT   decode_cnt;  
} DECODE_STAGE_REG; 

typedef struct packed {
    MULT_OPERAND sum; 
    MULT_OPERAND mplier;  
    MULT_OPERAND mcand; 
    MULT_FUNC func;  
} MULT_PACKET_INTERNAL; 


`ifndef SYNTH 
    function automatic void print_mult_packet_internal(input MULT_PACKET_INTERNAL mult_packet);
        $display("-----------MULT Packet Internal----------");
        $display("sum: %0d", mult_packet.sum);        // Assuming MULT_OPERAND is numeric
        $display("mplier: %0d", mult_packet.mplier);  // Assuming MULT_OPERAND is numeric
        $display("mcand: %0d", mult_packet.mcand);    // Assuming MULT_OPERAND is numeric
        // $display("func: %s", mult_packet.func.name()); // Assuming MULT_FUNC is an enum with a name() method
        $display("---------------------------------------");
    endfunction
`endif 
typedef struct packed {
    ADDR        addr;
    MEM_BLOCK   data;
    BYTE_MASK   mask;
    LSQ_IDX     entry_idx;
    MEM_SIZE    mem_size; 
} LSQ_ENTRY; 

typedef struct packed {
    LSQ_ENTRY [`LSQ_DEPTH-1:0] lsq_entry;
    logic [`LSQ_DEPTH-1:0] ready;
    logic [`LSQ_DEPTH-1:0] retired;
    FIFO_STATE state;
    LSQ_IDX    tail;  
    LSQ_IDX    head;  
    LSQ_SPACE  lsq_size;
} LSQ_QUEUE;

typedef struct packed {
    logic valid; // this indicates whether the FU should be taking this packet  
    DECODER_PACKET decoder_packet; 
    PREG_IDX  t; 
    PREG_IDX  t1; // maybe we don't need this 
    PREG_IDX  t2; // maybe we don't need this 

    FU_TAG     tag; 
    BMASK      b_mask;
    BRANCH_TAG branch_tag;
    
    DATA      rs1_value; // to be read from regfile 
    DATA      rs2_value; // to be read from regfile 

    DATA      result_value; // to be calculated, initialized to 0 
    
    // mult
    MULT_PACKET_INTERNAL mult_packet;

    // branch prediction related 
    logic    branch_taken; 
    ADDR     branch_target; 
    logic    branch_prediction_outcome; 

    // for MEM, we don't have mem stage anymore 
    MEM_BLOCK load_block_data; // to be used in block to block
    ADDR      load_addr; // store addr is result_value
    LSQ_IDX   entry_idx;
    MEM_SIZE mem_size; 
    logic    rd_unsigned;
} EXECUTE_PACKET; 


`ifndef SYNTH 
    function automatic void print_execute_packet(input EXECUTE_PACKET execute_packet);
        $display("-----------EXECUTE Packet----------");
        $display("valid: %0d", execute_packet.valid);
        print_decoder_packet(execute_packet.decoder_packet);
        $display("t: %0d t1: %0d t2: %0d", execute_packet.t, execute_packet.t1, execute_packet.t2);
        // $display("tag: %s b_mask: %0d branch_tag: %0d", execute_packet.tag.name(), execute_packet.b_mask, execute_packet.branch_tag);
        $display("rs1_value: %0d rs2_value: %0d result_value: %0d", execute_packet.rs1_value, execute_packet.rs2_value, execute_packet.result_value);
        print_mult_packet_internal(execute_packet.mult_packet);
        $display("branch_taken: %0d branch_target: %h branch_prediction_outcome: %0d", execute_packet.branch_taken, execute_packet.branch_target, execute_packet.branch_prediction_outcome);
        // $display("mem_size: %s rd_unsigned: %0d", execute_packet.mem_size.name(), execute_packet.rd_unsigned);
        $display("-----------------------------------");
    endfunction
`endif 

function automatic COMMIT_PACKET execute_to_commit_packet(input EXECUTE_PACKET execute_packet); 
    COMMIT_PACKET commit_packet; 
    commit_packet = 0; 
    if(execute_packet.valid) begin 
        commit_packet.NPC = execute_packet.decoder_packet.fetch_packet.NPC; 
        commit_packet.data = execute_packet.branch_taken ? execute_packet.decoder_packet.fetch_packet.NPC : execute_packet.result_value; 
        commit_packet.reg_idx = execute_packet.decoder_packet.dest_reg_idx; 
        commit_packet.halt = execute_packet.decoder_packet.halt; 
        commit_packet.illegal = execute_packet.decoder_packet.illegal; 
        commit_packet.valid = execute_packet.valid; 
    end 
    return commit_packet; 
endfunction 


`ifndef SYNTH 
    function automatic void print_commit_packet(input COMMIT_PACKET commit_packet);  
        $display("-----------commit packet----------"); 
        $display("valid: %b", commit_packet.valid);  
        $display("halt: %b", commit_packet.halt); 
        $display("illegal: %b", commit_packet.illegal); 
        $display("NPC: %h", commit_packet.NPC); 
        $display("data: %h", commit_packet.data); 
        $display("reg_idx: %d", commit_packet.reg_idx); 
        $display("----------------------------------"); 
    endfunction
`endif 


// mult_packet
typedef struct packed {
    DATA rs1; 
    DATA rs2;
    MULT_FUNC func;  
    DATA result; 
} MULT_PACKET;

function automatic EXECUTE_PACKET EXECUTE_PACKET_NULL();
    EXECUTE_PACKET packet;
    packet = 0; 
    packet.decoder_packet = DECODER_PACKET_NULL(); 
    packet.valid = 0; 
    packet.t = 0; 
    packet.t1= 0; 
    packet.t2= 0; 
    packet.rs1_value = 0; 
    packet.rs2_value = 0; 
    packet.result_value = 0; 
    packet.branch_taken = 0; 
    packet.branch_target = 0; 
    packet.branch_prediction_outcome = 0; 
    packet.mem_size = MEM_SIZE'(packet.decoder_packet.fetch_packet.inst.r.funct3[1:0]); 
    packet.rd_unsigned = packet.decoder_packet.fetch_packet.inst.r.funct3[2]; 
    return packet;
endfunction

// instruction buffer 
`define IB_DEPTH 4 
`define IB_IDX_WIDTH $clog2(`IB_DEPTH) 
typedef logic[`IB_IDX_WIDTH:0] IB_SPACE; 

// freelist 
typedef logic[`PREG_IDX_WIDTH:0] FL_SPACE; 
typedef logic[`PREG_NUM-1:0] FREELIST; 

`ifndef SYNTH 
    function automatic void print_freelist(input FREELIST freelist);  
        $display("-----------------------freelist-------------------------"); 
        for(int i = 0;i<`PREG_NUM;i++) begin 
            if(freelist[i]) $write("%d ", i); 
        end 
        $display("\n-------------------------------------------------------"); 
    endfunction
`endif 

// maptable 
`define TREQ_NUM 3 
typedef logic [`SUPERSCALAR_WAYS-1:0][`TREQ_NUM-1:0] MT_READ_ENABLE_MASK; 
typedef logic [`SUPERSCALAR_WAYS-1:0][`TREQ_NUM-1:0] MT_T_READY; 
typedef logic [`AREG_NUM-1:0] MT_READY_TABLE; 
typedef logic [`PREG_NUM-1:0] MT_PREG_READY_TABLE; 
typedef PREG_IDX[`AREG_NUM-1:0] MT_MAPTABLE;
typedef struct packed {
    MT_MAPTABLE map_table;
    // MT_READY_TABLE ready_table;
    MT_PREG_READY_TABLE preg_ready_table; 
} MAPTABLE;


`ifndef SYNTH 
    function automatic void print_maptable(input MAPTABLE  maptable); 
        $display("----------------------MAPTABLE---------------------------------"); 
        for(int i = 0;i<`AREG_NUM;i++) begin 
            // $display("AREG: %d PREG: %d ready: %b", i, maptable.map_table[i], maptable.ready_table[i]); 
            $display("AREG: %d PREG: %d ready: %b", i, maptable.map_table[i], maptable.preg_ready_table[maptable.map_table[i]]); 
        end 
        $display("---------------------------------------------------------------"); 
    endfunction 
`endif 

// rob 
`define ROB_DEPTH `ROB_SZ 
`define ROB_IDX_WIDTH $clog2(`ROB_DEPTH) 
typedef struct packed {
    PREG_IDX t; 
    PREG_IDX t_old; 
    // COMMIT_PACKET commit_packet; 
    ADDR     pc; 
} ROB_ENTRY;
typedef logic [`ROB_IDX_WIDTH:0] ROB_SPACE; 
typedef logic [`ROB_IDX_WIDTH-1:0] ROB_IDX; 


`ifndef SYNTH 
    function automatic void print_rob_entry(input ROB_ENTRY rob_entry);
        $display("-----------ROB Entry----------");
        $display("t: %d", rob_entry.t); 
        $display("t_old: %d", rob_entry.t_old); 
        $display("pc: %h(%d in decimal)", rob_entry.pc, rob_entry.pc); 

        // Reuse the existing function to print the commit_packet
        // print_commit_packet(rob_entry.commit_packet); 

        $display("----------------------------------");
    endfunction
`endif 


// branch stack
typedef struct packed {
    logic valid; 
    BMASK b_mask;

    BMASK prev_b_mask; 
    FREELIST freelist; 
    MAPTABLE maptable; 
    ROB_IDX  rob_tail; 
} BS_ENTRY;   
typedef struct packed {
    BMASK resolve_branch_mask; 
    BRANCH_TAG resolve_branch_tag;  
    logic prediction_outcome; 
} BS_RESOLVE_PACKET; 


`ifndef SYNTH 
    function automatic void print_bs_entry(input BS_ENTRY bs_entry);
        $display("---------- BS_ENTRY ----------");
        $display("Valid: %b", bs_entry.valid);
        $display("b_mask: %b", bs_entry.b_mask);
        $display("prev_b_mask: %b", bs_entry.prev_b_mask);
        $display("Freelist: %p", bs_entry.freelist);
        $display("Maptable: %p", bs_entry.maptable);
        $display("ROB Tail: %d", bs_entry.rob_tail);
        $display("------------------------------");
    endfunction
`endif 


`ifndef SYNTH 
    function automatic void print_bs_resolve_packet(input BS_RESOLVE_PACKET bs_resolve_packet);
        $display("---------- BS_RESOLVE_PACKET ----------");
        $display("prediction_outcome: %b", bs_resolve_packet.prediction_outcome); 
        $display("resolve_branch_mask: %b resolve_branch_tag: %b", bs_resolve_packet.resolve_branch_mask, bs_resolve_packet.resolve_branch_tag); 
        $display("------------------------------");
    endfunction
`endif 

// rs 
`define RS_DEPTH `RS_SZ
`define RS_IDX_WIDTH $clog2(`RS_DEPTH)  
typedef struct packed {
    FU_TAG tag; 
    BMASK b_mask; 
    BRANCH_TAG branch_tag;
    
    logic ready_t1; 
    
    logic ready_t2; 

    PREG_IDX t; 
    PREG_IDX t1; 
    PREG_IDX t2; 

    DECODER_PACKET decoder_packet;  
} RS_ENTRY; 
typedef logic [`RS_IDX_WIDTH:0] RS_SPACE; 


`ifndef SYNTH 
    function automatic void print_rs_entry(input RS_ENTRY rs_entry);
        $display("-----------RS_ENTRY----------");
        
        // Print the ready flags
        $display("ready_t1: %0d, ready_t2: %0d", rs_entry.ready_t1, rs_entry.ready_t2);
        
        // Print the registers
        $display("t: %0d, t1: %0d, t2: %0d", rs_entry.t, rs_entry.t1, rs_entry.t2);
        
        // Print the tags
        // $display("tag: %s, b_mask: %0d, branch_tag: %0d", rs_entry.tag.name(), rs_entry.b_mask, rs_entry.branch_tag);
        
        // Print the decoder packet details
        print_decoder_packet(rs_entry.decoder_packet); // Assuming this function is defined elsewhere
        
        $display("-----------------------------------");
    endfunction
`endif 

// btb 
typedef logic[`BTB_INST_PC_IDX_WIDTH-1:0] BTB_IDX; 
typedef logic[`BTB_INST_PC_TAG_WIDTH-1:0] BTB_TAG; 
typedef logic[`BTB_DST_PARTIAL_PC_WIDTH-1:0] BTB_PARTIAL_DST_PC; 

typedef struct packed {
    BTB_TAG src_tag; 
    BTB_PARTIAL_DST_PC dst_partial_pc;   
    logic valid; // indicate if entry is valid, we never clear this though since this is not cache.  
} BTB_ENTRY; 

// instruction queue
typedef enum logic [1:0] {
    EMPTY,
    NON_EMPTY
} FIFO_STATE;


typedef logic[7:0] BYTE_MASK; // this is the 8 bit mask indicating which bytes are modified in a memory block 
typedef logic [`LOAD_NUM-1:0] LSQ_LOAD_MASK; 
// when passed into dcache, this is a one-hot encoding indicating which load this is 
// when returned from dcache, this is a mask indicating which loads have been served 
typedef struct packed {
    // ADDR addr;              // address of memory access 
    // DATA data;              // data 
    MEM_BLOCK_ADDR      block_addr; 
    MEM_BLOCK           block_data; 
    BYTE_MASK           byte_mask; 
    // LSQ_LOAD_MASK load_mask;// load mask 
    // MEM_SIZE mem_size; 
    logic is_load;          // indicates if this is a load request 
} DCACHE_REQUEST;


`ifndef SYNTH 
    function automatic void print_dcache_request(input DCACHE_REQUEST request); 
        $display("---------------------------dcache request--------------------------"); 
        $display("is_load: %b", request.is_load); 
        // $display("addr: %b(%d in decimal) data: %h", request.addr, request.addr, request.data);  
        
        $display("block_addr: %b(%d in decimal) block data: %h byte_mask: %b", request.block_addr, request.block_addr, request.block_data, request.byte_mask);   
        // $display("mem_size: %s", request.mem_size.name()); 
        $display("-------------------------------------------------------------------"); 
    endfunction
`endif 

typedef enum logic[2:0] { 
    MSHR_INVALID,    // default state 
    // Note: The DISPATCHED state is deprecated because a memory request is immediately issued when an MSHR entry is allocated, this is because dcache has the highest priority and memory takes 1 request per cycle. 
    MSHR_DISPATCHED, // the entry is dispatched, waiting for issue to the memory  
    MSHR_ISSUED,     // the entry is issued (also dispatched), now waiting for memory block to come back 
    MSHR_LOADED,     // the entry is loaded, now waiting for writting back to dcache 
    // Note: maybe we don't need this state, because there will only be at most 1 mem response per cycle, if this matches a MSHR entry, then we immediately write the returned block to dcache's line. 
    MSHR_WRITTEN    
    // Note: maybe we don't need this for the same reason. 
 } MSHR_ENTRY_STATE;

`define DCACHE_MSHR_NUM 16 // this is 16 because we want to use mem tx tag to directly index the entries 
typedef struct packed {
    MSHR_ENTRY_STATE state; 
    MEM_BLOCK_ADDR block_addr;       
    BYTE_MASK      byte_mask;        // 
    MEM_BLOCK      merged_data;      // store data + returned memory load data 
    // LSQ_LOAD_MASK  merged_load_mask; // merged by OR, this indicates this entry can be used to serve which load fus  
    // MEM_TAG         mem_tx_tag; 
} DCACHE_MSHR_ENTRY; 
// Note: For loads, if a store entry is issued, loads don't need to be issued again, since we load the block from the memory first.  
// When a memory response returns, we immediately process the merged data and return the merged entry to LSQ, and this entry will be retired. 


`ifndef SYNTH 
    function automatic void print_mshr_entry(input DCACHE_MSHR_ENTRY entry); 
        $display("---------------------------dcache mshr entry--------------------------"); 
        // $display("state: %s", entry.state.name()); // enum state cannot pass make syn, comment out for comvenient
        $display("byte_mask: %b", entry.byte_mask);  
        $display("block_addr: %b(%d in decimal) data: %h", entry.block_addr, entry.block_addr, entry.merged_data);   
        $display("tag: %h(%b)",entry.block_addr.idx_and_tag.tag, entry.block_addr.idx_and_tag.tag); 
        $display("-------------------------------------------------------------------"); 
    endfunction
`endif 

typedef struct packed {
    logic valid;            
    ADDR addr;          
    logic branch_taken; 
    logic branch_prediction_outcome; 
} CORRECTNESS_PACKET;

typedef struct packed {
    MEM_BLOCK_ADDR block_addr; 
    MEM_BLOCK      block_data; 
} DCACHE_RESPONSE;

`ifndef SYNTH 
    function automatic void print_dcache_response(input DCACHE_RESPONSE response); 
        $display("---------------------------dcache response--------------------------");  
        $display("block_addr: %b(%d in decimal) data: %h", response.block_addr, response.block_addr, response.block_data);   
        $display("-------------------------------------------------------------------"); 
    endfunction
`endif 

// this extends block address to address to be passed to memory 
function automatic ADDR block_addr_to_addr (input MEM_BLOCK_ADDR block_addr); 
    return {block_addr, 3'b0}; 
endfunction 

// this function masks the input block data with the byte mask 
function automatic MEM_BLOCK mask_block_data(input BYTE_MASK input_byte_mask, input MEM_BLOCK input_block_data); 
    MEM_BLOCK block;
    block = 0;  
    for(int i = 0;i<8;i++) begin 
        if(input_byte_mask[i]) begin 
            block.byte_level[i] = input_block_data.byte_level[i];
        end else begin 
            block.byte_level[i] = 0; 
        end  
    end 
    return block; 
endfunction 


// construct an address based on cache index, tag, and block offset 
function automatic ADDR idx_tag_offset_to_addr(input CACHE_IDX idx, input CACHE_TAG tag, input logic [2:0] offset); 
    ADDR addr; 
    addr = 0;
    addr = {tag, idx, offset}; 
    return addr; 
endfunction 

// this function constructs a block address given cache index and tag, this is mostly for testing 
function automatic MEM_BLOCK_ADDR idx_tag_to_block_addr(input CACHE_IDX idx, input CACHE_TAG tag); 
    MEM_BLOCK_ADDR block_addr; 
    block_addr = 0;
    block_addr = {tag, idx}; 
    return block_addr; 
endfunction 

// this function takes an address and the mem size, and calculates the access byte mask (8 bits)
function automatic BYTE_MASK get_byte_mask(input ADDR addr, input MEM_SIZE mem_size); 
    BYTE_MASK mask; 
    mask = 0; 
    if(mem_size==BYTE) begin 
        for(int i = 0;i<1 && addr.cache_block_addr.reserved+i<8;i++)
            mask[addr.cache_block_addr.reserved+i] = 1;
    end else if (mem_size==HALF) begin
        for(int i = 0;i<2 && addr.cache_block_addr.reserved+i<8;i++)  
            mask[addr.cache_block_addr.reserved+i] = 1; 
    end else if (mem_size==WORD) begin
        for(int i = 0;i<4 && addr.cache_block_addr.reserved+i<8;i++)  
            mask[addr.cache_block_addr.reserved+i] = 1;
    end else begin 
        for(int i = 0;i<8 && addr.cache_block_addr.reserved+i<8;i++)  
            mask[addr.cache_block_addr.reserved+i] = 1;
    end     
    return mask; 
endfunction

// this function takes address, data, mem size to align the data to a mem block
// e.g. addr=4, data=0x6a, mem_size=HALF --> 006a0000 
// this is pretty similar to get_byte_mask 
function automatic MEM_BLOCK align_data_to_block(input ADDR addr, input DATA data, input MEM_SIZE mem_size);  
    MEM_BLOCK block;  
    block = 0; 
    if(mem_size==BYTE) begin 
        for(int i = 0; i<1 && i+addr.cache_block_addr.reserved<8;i++) begin 
            block.byte_level[i+addr.cache_block_addr.reserved] = data.byte_level[i]; 
        end 
    end else if (mem_size==HALF) begin
        for(int i = 0;i<2 && i+addr.cache_block_addr.reserved<8;i++) begin 
            block.byte_level[i+addr.cache_block_addr.reserved] = data.byte_level[i]; 
        end 
    end else if (mem_size==WORD) begin
        for(int i = 0;i<4 && i+addr.cache_block_addr.reserved<8;i++) begin 
            block.byte_level[i+addr.cache_block_addr.reserved] = data.byte_level[i]; 
        end 
    end else begin // this is not happening. 
        for(int i = 0;i<8 && i+addr.cache_block_addr.reserved<8;i++) begin 
            block.byte_level[i+addr.cache_block_addr.reserved] = data.byte_level[i]; 
        end 
    end     
    return block; 
endfunction 

// this function will merge the input_byte_mask with merged_byte_mask and update merged_byte_mask and also merge data based on input_byte_mask 
// this is only for stores 
function automatic void merge_byte_mask_and_data(input MEM_BLOCK input_block, input BYTE_MASK input_byte_mask, input MEM_BLOCK old_block, input BYTE_MASK old_byte_mask,  output MEM_BLOCK merged_block, output BYTE_MASK merged_byte_mask); 
    merged_block = old_block; 
    merged_byte_mask = old_byte_mask | input_byte_mask; 
    for(int i = 0;i<8;i++) begin 
        if(input_byte_mask[i]) begin 
            merged_block.byte_level[i] = input_block.byte_level[i];  
        end 
    end 
endfunction    

// this function takes load and store's byte mask and block address, and returns whether we can forward the store to the load on a byte level. 
function automatic logic can_forward_store_to_load(input BYTE_MASK load_mask, input MEM_BLOCK_ADDR load_block_addr, input BYTE_MASK store_mask, input MEM_BLOCK_ADDR store_block_addr); 
    return ((load_mask & store_mask) == load_mask) & (load_block_addr == store_block_addr); 
endfunction

// Function to print instruction string based on opcode
// Function to print instruction string based on opcode

`ifndef SYNTH 
    function automatic void print_instr_name(
        INST inst_union 
    );
        //logic [6:0] opcode;
        //logic [2:0] funct3;
        //logic [6:0] funct7;
        // string instr_str;
        logic [31:0] instr_str; 
        logic [6:0] opcode;
        opcode = inst_union.inst[6:0];  

        begin
            case (opcode)
                7'b0010011: begin // I-type
                    case (inst_union.i.funct3)
                        3'b000: instr_str = "addi  ";
                        3'b010: instr_str = "slti  ";
                        3'b011: instr_str = "sltiu ";
                        3'b100: instr_str = "xori  ";
                        3'b110: instr_str = "ori   ";
                        3'b111: instr_str = "andi  ";
                        3'b001: instr_str = "slli  ";
                        3'b101: begin
                            case (inst_union.r.funct7)
                                7'b0000000: instr_str = "srli  ";
                                7'b0100000: instr_str = "srai  ";
                                default: instr_str = "xxx   ";
                            endcase
                        end
                        default: instr_str = "xxx   ";
                    endcase
                end
                
                7'b0110011: begin // R-type
                    case (inst_union.r.funct3)
                        3'b000: begin
                            case (inst_union.r.funct7)
                                7'b0000000: instr_str = "add   ";
                                7'b0100000: instr_str = "sub   ";
                                default: instr_str = "xxx   ";
                            endcase
                        end
                        3'b001: instr_str = "sll   ";
                        3'b010: instr_str = "slt   ";
                        3'b011: instr_str = "sltu  ";
                        3'b100: instr_str = "xor   ";
                        3'b101: begin
                            case (inst_union.r.funct7)
                                7'b0000000: instr_str = "srl   ";
                                7'b0100000: instr_str = "sra   ";
                                default: instr_str = "xxx   ";
                            endcase
                        end
                        3'b110: instr_str = "or    ";
                        3'b111: instr_str = "and   ";
                        default: instr_str = "xxx   ";
                    endcase
                end
                
                7'b0000011: begin // Load instructions
                    case (inst_union.i.funct3)
                        3'b000: instr_str = "lb    ";
                        3'b001: instr_str = "lh    ";
                        3'b010: instr_str = "lw    ";
                        3'b100: instr_str = "lbu   ";
                        3'b101: instr_str = "lhu   ";
                        default: instr_str = "xxx   ";
                    endcase
                end
                
                7'b0100011: begin // Store instructions
                    case (inst_union.s.funct3)
                        3'b000: instr_str = "sb    ";
                        3'b001: instr_str = "sh    ";
                        3'b010: instr_str = "sw    ";
                        default: instr_str = "xxx   ";
                    endcase
                end
                
                7'b1100011: begin // Branch instructions
                    case (inst_union.b.funct3)
                        3'b000: instr_str = "beq   ";
                        3'b001: instr_str = "bne   ";
                        3'b100: instr_str = "blt   ";
                        3'b101: instr_str = "bge   ";
                        3'b110: instr_str = "bltu  ";
                        3'b111: instr_str = "bgeu  ";
                        default: instr_str = "xxx   ";
                    endcase
                end
                
                7'b0110111: instr_str = "lui   ";
                7'b0010111: instr_str = "auipc ";
                7'b1101111: instr_str = "jal   ";
                7'b1100111: instr_str = "jalr  ";

                7'b1110011: begin
                    case (inst_union.inst)
                        {25'b0, 7'b1110011}: instr_str = "ecall ";
                        {12'b1, 13'b0, 7'b1110011}: instr_str = "ebreak";
                        {12'b000100000101, 13'b0, 7'b1110011}: instr_str = "wfi   ";
                        default: instr_str = "xxx   ";
                    endcase
                end

                7'b0110011: begin
                    case (inst_union.r.funct3)
                        3'b000: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "mul   "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b001: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "mulh  "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b010: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "mulsu "; 
                            else
                                instr_str = "xxx   ";
                        end
                        3'b011: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "mulu  "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b100: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "div   "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b101: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "divu  "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b110: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "rem   "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        3'b111: begin
                            if (inst_union.r.funct7 == 7'b0000001)
                                instr_str = "remu  "; 
                            else
                                instr_str = "xxx   "; 
                        end
                        default: instr_str = "xxx   "; 
                    endcase
                end


                default: instr_str = "xxx   ";
            endcase
            
            $display("------------------------");
            $display("Instruction Decoded:");
            $display("opcode: %b", opcode);
            $display("instruction: %s", instr_str);
            $display("------------------------");
        end
    endfunction
`endif 

`endif // __SYS_DEFS_SVH__