`include "sys_defs.svh"

/* in this code we use the sq only
    and for the load instruction we only allow it issue when all of the store instructions before it has completed
    there is no load queue
*/

module lsq(
    input clock, reset,
    // start dispatch
    input logic     [`SUPERSCALAR_WAYS - 1 : 0] dispatch_is_store,  // the store insts dispatched in this cycle;
    input logic     [`SUPERSCALAR_WAYS - 1 : 0] dispatch_is_load,   // the load insts dispatched in this cycle;
    //output LSQ_IDX  [`SUPERSCALAR_WAYS - 1 : 0] dispatch_load_indexes, // to compute how many store before this load?
    // nego with dispatch
    output LSQ_SPACE                            remain, // how many store next cycle could dispatch
    output LSQ_IDX                              current_tail,
    // end dispatch

    // start FU
    // input from FU, need store's&load's addr and index, store's data,
    input logic     [`NUM_FU_STORE - 1 : 0]      fu_store_enable,  // whether the fu's data is valid
    input logic                                  fu_load_enable, // whether the fu's data is valid 
    input EXECUTE_PACKET [`NUM_FU_STORE - 1 : 0] fu_store_packet,  // the store entity completed in this cycle;
    input EXECUTE_PACKET                         fu_load_packet, // only addr and size is vaild when input this packet   
    // end FU

    // input from ROB(retire stage)
    input logic     [`SUPERSCALAR_WAYS - 1 :0]   ROB_retire_enable,   

    // branch recovery
    input logic                                  recover_enable,
    input LSQ_IDX                                recover_tail,

    // start Dcache
    // if 1. there's a cache miss 2. MSHR is full 3. no block address match in MSHR, then the request is not served 
    input logic                                  dcache_request_valid,   
    input logic                                  dcache_response_valid, // indicates whether there is a dcache response available 
    input DCACHE_RESPONSE                        dcache_response,  // the mshr entry to be sent back as a response 
    // output the entry when request for access the Dcache, after that, we set the ready bit to 1 
    output logic                                 request_to_dcache_enable,
    output DCACHE_REQUEST                        request_to_dcache_packet,
    // end Dcache


    // start block to block
    input logic                                  load_done, // output the data
    output logic                                 load_can_cdb, // start signal
    output EXECUTE_PACKET                        load_result_packet
    // end block to block
);
    // convert input EXECUTE_PACKET to store_entry
    MEM_BLOCK       [`NUM_FU_STORE - 1 : 0]     store_entry_data_block;     
    MEM_BLOCK_ADDR  [`NUM_FU_STORE - 1 : 0]     store_entry_block_addr;
    MEM_SIZE        [`NUM_FU_STORE - 1 : 0]     store_entry_data_size;
    always_comb begin
        for(int i=0; i<`NUM_FU_STORE; i++) begin
            store_entry_data_block[i] = fu_store_packet[i].rs1_value;
            store_entry_block_addr[i] = fu_store_packet[i].result_value;
            store_entry_data_size[i] = fu_store_packet[i].mem_size;
        end
    end

    // TODO: 3 bits enable
    LSQ_QUEUE                                   current_lsq , next_lsq; // state
    LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     head_idx;  // head+0, head+1, head+2
    LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     tail_idx;  // tail+0, tail+1, tail+2

    // WAIT stage
    logic                                       load_wait_store_addr;   // use for stall load 1 means the load can not go into sq
    // ISSUE stage
    logic                                       load_request_dcache_enable; // request Dcache to access the data
    logic                                       store_request_dcache_enable; // request Dcache to access the data
    logic                                       dcache_serve_load;  //  select
    logic                                       dcache_serve_store;

    
    assign remain = current_lsq.lsq_size;
    assign retire_cnt = $countones(ROB_retire_enable);  // fake retire cnt (1 store or load per cycle, so can't retire all)
    assign store_cnt = $countones(dispatch_is_store);
    assign pop_cnt = store_selected; // actual retire cnt, 0 or 1
    always_comb begin 
        for(int i=0; i<retire_cnt; i++) begin 
            head_idx[i] = (current_lsq.head+i)%`LSQ_DEPTH; 
        end 
        for(int i=0; i<store_cnt; i++) begin 
            tail_idx[i] = (current_lsq.tail+i)%`LSQ_DEPTH; 
        end 
    end 
    assign current_tail = current_lsq.tail;

    //update next_lsq, including the new element, head, and tail
    always_comb begin
        next_lsq = current_lsq;
        if (current_lsq.state == EMPTY &  store_cnt-pop_cnt > 0) begin 
            next_lsq.state = NON_EMPTY;  
        end else if (current_lsq.state == NON_EMPTY & (current_lsq.lsq_size-pop_cnt+store_cnt == 0)) begin 
            next_lsq.state = EMPTY; 
        end 
        for(int i=0; i<`SUPERSCALAR_WAYS; i++) begin
            if(dispatch_is_store[i]) begin    
                next_lsq.lsq_entry[tail_idx[i]] = '{default:'0};
                next_lsq.ready[tail_idx[i]] = 0;
                next_lsq.retired[tail_idx[i]] = 0;
                next_lsq.lsq_entry[tail_idx[i]].entry_idx = tail_idx[i];
            end
        end
        for(int i=0; i<retire_cnt; i++) begin
            next_lsq.retired[head_idx[i]] = 1;
        end
        for(int i=0; i<`NUM_FU_STORE; i++) begin
            if(fu_store_enable[i]) begin
                next_lsq.lsq_entry[fu_store_packet.entry_idx].data = store_entry_data_block[i];
                next_lsq.lsq_entry[fu_store_packet.entry_idx].addr = store_entry_block_addr[i];
                next_lsq.lsq_entry[fu_store_packet.entry_idx].mem_size = store_entry_data_size[i];
                next_lsq.ready[fu_store_packet.entry_idx] = 1;
            end
        end
        next_lsq.tail = (next_lsq.tail+store_cnt)%`LSQ_DEPTH;
        next_lsq.head = (next_lsq.head+pop_cnt)%`LSQ_DEPTH;
    end
    

    //FSM
    always_ff@(posedge clock)begin
        if(reset)begin
            current_lsq.lsq_entry <= '{default: '0};
            current_lsq.ready <= '{default: '0};
            current_lsq.retired <= '{default: '0};
            current_lsq.state <= EMPTY;
            current_lsq.head <= 0;
            current_lsq.tail <= 0;
            current_lsq.lsq_size <= 0;
        end else begin
            current_lsq <= next_lsq;
        end
    end

