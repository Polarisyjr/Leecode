`include "sys_defs.svh"

/* in this code we use the sq only
    and for the load instruction we only allow it issue when all of the store instructions before it has completed
    there is no load queue
*/

module lsq(
    input clock, reset,
    // start dispatch
    input logic                                 dispatch_is_store,  // the store insts dispatched in this cycle; VER1: only one store per cycle
    input logic     [`SUPERSCALAR_WAYS - 1 : 0] dispatch_is_load,   // the load insts dispatched in this cycle;
    //output LSQ_IDX  [`SUPERSCALAR_WAYS - 1 : 0] dispatch_load_indexes, // to compute how many store before this load?
    // nego with dispatch
    output LSQ_SPACE                            remain, // how many store next cycle could dispatch
    output LSQ_IDX                              current_tail,
    output logic                                full,
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
        for(int i=0; i<`NUM_FU_STORE; i++) begin  // result_value-->addr; rs2-->store_data
            store_entry_data_block[i] = align_data_to_block(fu_store_packet[i].result_value, fu_store_packet[i].rs2_value, fu_store_packet[i].mem_size);
            store_entry_block_addr[i].addr = fu_store_packet[i].result_value[31:`BYTE_ADDR_BITS]; // 3 bits offset
            store_entry_data_size[i]  = fu_store_packet[i].mem_size; // 1 or 2 or 4 or 8 bytes?
        end
    end

    LSQ_QUEUE                                   current_lsq , next_lsq; // state
    LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     head_idx;  // head+0, head+1, head+2
    //LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     tail_idx;  // tail+0, tail+1, tail+2; VER1: at most 1

    // WAIT stage
    logic                                       load_wait_store_addr;   // use for stall load 1 means the load can not go into sq
    // ISSUE stage
    logic                                       load_request_dcache_enable; // request Dcache to access the data
    logic                                       store_request_dcache_enable; // request Dcache to access the data
    logic                                       dcache_serve_load;  // select bit
    logic                                       dcache_serve_store;

    
    assign retire_cnt = $countones(ROB_retire_enable);  // fake retire cnt (1 store or load in dcache per cycle, so can't retire all)
    assign pop_cnt = dcache_serve_store; // actual retire cnt, 0 or 1
    assign store_cnt = dispatch_is_store; //$countones(); VER1: at most one
    always_comb begin 
        for(int i=current_lsq.head; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
            if(current_lsq.entry_state[i] != RETIRED) begin // find the latest one that hasn't retired
                for(int j=0; j<retire_cnt; j++) begin // ROB retired, but lsq haven't
                    head_idx[j] = (current_lsq.head+j)%`LSQ_DEPTH; 
                end
                break; // end search
            end
        end
        /* 
        for(int i=0; i<retire_cnt; i++) begin 
            head_idx[i] = (current_lsq.head+i)%`LSQ_DEPTH; 
        end 
        VER1: at most one
        for(int i=0; i<store_cnt; i++) begin 
            tail_idx[i] = (current_lsq.tail+i)%`LSQ_DEPTH; 
        end */
    end 

    // for nego
    assign remain = current_lsq.lsq_size;
    assign current_tail = current_lsq.tail;
    assign full = (current_lsq.state == NON_EMPTY) & (current_lsq.head == current_lsq.tail)
    
    //update next_lsq, including the new element, head, and tail
    always_comb begin
        next_lsq = current_lsq;
        if (recover_enable) begin // branch recover
            if (current_lsq.head == recover_tail) begin // if all store before that branch has retired, then empty
                next_lsq.state = EMPTY; 
            end // reset all store after that branch
            for(int i=recover_tail; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
                next_lsq.entry_state[current_lsq.tail] = INVALID;
            end // update the new tail
            next_lsq.tail = recover_tail;
        end
        else begin // update the state of lsq
            if (current_lsq.state == EMPTY &  store_cnt-pop_cnt > 0) begin 
                next_lsq.state = NON_EMPTY;  
            end else if (current_lsq.state == NON_EMPTY & (current_lsq.lsq_size-pop_cnt+store_cnt == 0)) begin 
                next_lsq.state = EMPTY; 
            end 
            /*for(int i=0; i<`SUPERSCALAR_WAYS; i++) begin
                if(dispatch_is_store[i]) begin    
                    next_lsq.lsq_entry[tail_idx[i]] = '{default:'0};
                    next_lsq.ready[tail_idx[i]] = 0;
                    next_lsq.retired[tail_idx[i]] = 0;
                    next_lsq.lsq_entry[tail_idx[i]].entry_idx = tail_idx[i];
                end
            end*/
            if(dispatch_is_store) begin  // push the new valid element to the tail
                next_lsq.lsq_entry[current_lsq.tail] = '{default:'0};
                next_lsq.lsq_entry[current_lsq.tail].entry_idx = current_lsq.tail;
                next_lsq.entry_state[current_lsq.tail] = WAITING; // waiting for FU computation
            end
            for(int i=0; i<`NUM_FU_STORE; i++) begin
                if(fu_store_enable[i]) begin // FU execute_packet update the corresponding lsq entry
                    next_lsq.lsq_entry[fu_store_packet.entry_idx].data = store_entry_data_block[i];
                    next_lsq.lsq_entry[fu_store_packet.entry_idx].addr = store_entry_block_addr[i];
                    next_lsq.lsq_entry[fu_store_packet.entry_idx].mem_size = store_entry_data_size[i];
                    next_lsq.entry_state[fu_store_packet.entry_idx] = READY; 
                end // now ready, if all store before a load is ready, then the load could start to compute the mask
            end
            for(int i=0; i<retire_cnt; i++) begin // ROB retired, but lsq haven't
                next_lsq.entry_state[head_idx[i]] = RETIRED;  // after that, the head would request for dcache
            end
            if(pop_cnt) begin
                next_lsq.entry_state[current_lsq.head] = INVALID; // this entry is already empty in lsq 
            end
            next_lsq.tail = (next_lsq.tail+store_cnt)%`LSQ_DEPTH;
            next_lsq.head = (next_lsq.head+pop_cnt)%`LSQ_DEPTH;
            next_lsq.lsq_size = next_lsq.lsq_size-pop_cnt+store_cnt;
        end
    end
    
    load_state_t current_load_state, next_load_state;
    always_comb begin
        next_load_state = current_load_state;
        case (current_load_state)
            INVALID: begin
                if(fu_load_enable) begin
                    next_load_state = WAITING;
                end
            end
            WAITING: begin
                if(!wait_store_before_load(fu_load_packet, current_lsq)) begin
                    next_load_state = FORWARD;
                end    
            end

            FORWARD: begin

            end

            ISSUE: begin

            end

            COMPLETED: begin

            end
        endcase
    end

    //FSM
    always_ff@(posedge clock)begin
        if(reset) begin
            current_load_state <= '{default: '0};
            current_lsq.lsq_entry <= '{default: '0};
            current_lsq.entry_state <= '{default: '0};
            current_lsq.state <= EMPTY;
            current_lsq.head <= 0;
            current_lsq.tail <= 0;
            current_lsq.lsq_size <= 0;
        end else begin
            current_lsq <= next_lsq;
            current_load_state <= next_load_state;
        end
    end


    // function

    function automatic logic wait_store_before_load(input EXECUTE_PACKET load_packet, input LSQ_QUEUE current_lsq);
        logic wait_lsq;
        wait_lsq = 0; 
        if(current_lsq.head == load_packet.entry_idx) begin
            return wait_lsq;   // all store before this load have retired, there's no need to wait 
        end
        else if(current_lsq.head < load_packet.entry_idx) begin // the below two can combine
            for(int j=current_lsq.head ; j<load_packet.entry_idx; j++)begin
                if (current_lsq.entry_state[j]!=READY) begin
                    wait_lsq = 1;
                    break;  // Exit loop early if any entry is not ready
                end
            end
        end else begin
            for (int j=current_lsq.head; j!=load_packet.entry_idx; j=(j+1)%`LSQ_DEPTH) begin
                if (current_lsq.entry_state[j]!=READY) begin
                    wait_lsq = 1;
                    break;  // Exit loop early if any entry is not ready
                end
            end
        end
        return wait_lsq;
    endfunction



/*// LOAD FSM
    load_state_t [`NUM_FU_STORE-1:0] current_load_state, next_load_state;
    always_comb begin
        for (int i = 0; i < `NUM_FU_STORE; i++) begin
            next_load_state[i] = current_load_state[i];
            case (current_load_state[i])
                INVALID: begin

                end
                WAITING: begin
                    if(!wait_store_before_load(fu_load_packet, current_lsq)) begin
                        next_load_state[i] = FORWARD;
                    end    
                end

                CAN_FORWARD: begin

                end

                CAN_ISSUE: begin

                end

                COMPLETED: begin

                end
            endcase
        end
    end
*/

/*always_comb begin
        for (int i = 0; i < `SUPERSCALAR_WAYS; i++) begin
            next_load_state[i] = current_load_state[i];
            case (current_load_state_array[i])
                INVALID: next_load_state[i] = dispatch_is_load[i] ? WAITING : INVALID;
                WAITING: next_load_state[i] = ( ~load_wait_store_addr & fu_load_enable & (fu_load_packet.entry_idx == //TODO )) ? CAN_FORWARDING : WAITING;
                CAN_FORWARDING: next_load_state[i] = load_can_forwarding ? COMPLETE : CAN_ISSUE;
                CAN_ISSUE: next_load_state[i] = dcache_request_valid & dcache_response_valid ? COMPLETE : CAN_ISSUE;
                COMPLETE : next_load_state[i] = load_can_cdb ? INVALID:COMPLETE;

                default: next_load_state[i] = INVALID;
            endcase
        end
    end*/