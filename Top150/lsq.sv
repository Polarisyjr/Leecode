`include "sys_defs.svh"

/* in this code we use the sq only
    and for the load instruction we only allow it issue when all of the store instructions before it has completed
    there is no load queue
*/

module lsq(
    input clock, reset,
    // start dispatch
    input logic                                 dispatch_is_store,  // the store insts dispatched in this cycle; VER1: only one store per cycle
    //input logic     [`SUPERSCALAR_WAYS - 1 : 0] dispatch_is_load,   // the load insts dispatched in this cycle;
    //output LSQ_IDX  [`SUPERSCALAR_WAYS - 1 : 0] dispatch_load_indexes, // to compute how many store before this load?
    // nego with dispatch
    output LSQ_SPACE                            remain, // how many store next cycle could dispatch
    output LSQ_IDX                              current_tail,
    output logic                                full,
    // end dispatch
    output logic                                empty,
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
    output logic                                 block_to_block_start, // start signal
    output EXECUTE_PACKET                        load_result_packet,
    // end block to block

    // start debug
    output LSQ_ENTRY [`SUPERSCALAR_WAYS - 1 : 0] current_lsq_retire_entry,
    output logic     [`SUPERSCALAR_WAYS - 1 : 0] current_lsq_retire_enable,
    output LSQ_QUEUE                             current_lsq_dbg,
    output LSQ_QUEUE                             next_lsq_dbg,
    output LSQ_LOAD_STATE                        current_load_state_dbg,
    output LSQ_LOAD_STATE                        next_load_state_dbg
);
    // convert input EXECUTE_PACKET to store_entry
    MEM_BLOCK       [`NUM_FU_STORE - 1 : 0]     store_entry_data_block;     
    MEM_BLOCK_ADDR  [`NUM_FU_STORE - 1 : 0]     store_entry_block_addr;
    MEM_SIZE        [`NUM_FU_STORE - 1 : 0]     store_entry_data_size;  
    MEM_BLOCK_ADDR                              load_entry_block_addr;
    MEM_SIZE                                    load_entry_data_size;
    BYTE_MASK                                   load_entry_byte_mask;
    //BYTE_MASK                                   store_head_entry_byte_mask;
    always_comb begin
        for(int i=0; i<`NUM_FU_STORE; i++) begin  // result_value-->addr; rs2-->store_data
            store_entry_data_block[i] = align_data_to_block(fu_store_packet[i].result_value, fu_store_packet[i].rs2_value, fu_store_packet[i].mem_size);
            store_entry_block_addr[i] = fu_store_packet[i].result_value[31:`BYTE_ADDR_BITS]; // 3 bits offset
            store_entry_data_size[i]  = fu_store_packet[i].mem_size; // 1 or 2 or 4 or 8 bytes?
        end
        load_entry_block_addr = fu_load_packet.result_value[31:`BYTE_ADDR_BITS]; // 3 bits offset
        load_entry_data_size  = fu_load_packet.mem_size; // 1 or 2 or 4 or 8 bytes?
        load_entry_byte_mask = get_byte_mask(fu_load_packet.result_value, fu_load_packet.mem_size); 
        //store_head_entry_byte_mask = get_byte_mask({current_lsq.lsq_entry[current_lsq.head].block_addr,000}, current_lsq.lsq_entry[current_lsq.head].mem_size); 
    end
    LSQ_SPACE                                   store_cnt_before_load_idx;
    LSQ_SPACE                                   store_cnt_before_recover_tail;
    always_comb begin
        if (current_lsq.head == fu_load_packet.entry_idx) begin 
            store_cnt_before_load_idx = 0; 
        end else if (fu_load_packet.entry_idx > current_lsq.head) begin 
            store_cnt_before_load_idx = fu_load_packet.entry_idx-current_lsq.head; 
        end else begin 
            store_cnt_before_load_idx = ROB_DEPTH-current_lsq.head+fu_load_packet.entry_idx; 
        end 
        if (current_lsq.head == recover_tail) begin 
            store_cnt_before_recover_tail = 0; 
        end else if (recover_tail > current_lsq.head) begin 
            store_cnt_before_recover_tail = recover_tail-current_lsq.head; 
        end else begin 
            store_cnt_before_recover_tail = ROB_DEPTH-current_lsq.head+recover_tail; 
        end 
    end

    LSQ_QUEUE                                   current_lsq , next_lsq; // state
    LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     head_idx;  // head+0, head+1, head+2
    //LSQ_IDX         [`SUPERSCALAR_WAYS-1:0]     tail_idx;  // tail+0, tail+1, tail+2; VER1: at most 1
    logic           [`SUPERSCALAR_IDX_WIDTH-1:0] retire_cnt;
    logic           [`SUPERSCALAR_IDX_WIDTH-1:0] store_cnt;
    logic                                        pop_cnt;

    // WAIT stage
    logic                                       load_wait_store_addr;   // use for stall load 1 means the load can not go into sq
    // ISSUE stage
    logic                                       load_request_dcache_enable; // request Dcache to access the data
    logic                                       store_request_dcache_enable; // request Dcache to access the data
    logic                                       dcache_serve_load;  // select bit
    logic                                       dcache_serve_store;

    
    assign retire_cnt = $countones(ROB_retire_enable);  // fake retire cnt (1 store or load in dcache per cycle, so can't retire all)
    assign pop_cnt = dcache_serve_store & dcache_request_valid; // actual retire cnt, 0 or 1
    assign store_cnt = dispatch_is_store; //$countones(); VER1: at most one
    always_comb begin 
        head_idx=0;
        for(int i=current_lsq.head; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
            if(current_lsq.entry_state[i] != LSQ_STORE_RETIRED) begin // find the latest one that hasn't retired
                for(int j=0; j<retire_cnt; j++) begin // ROB retired, but lsq haven't
                    head_idx[j] = (i+j)%`LSQ_DEPTH;                    
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
    assign remain = `LSQ_DEPTH-current_lsq.lsq_size;
    assign current_tail = current_lsq.tail;
    assign full = (current_lsq.state == NON_EMPTY) & (current_lsq.head == current_lsq.tail); 
    assign empty = current_lsq.state == EMPTY; 
    
    //update next_lsq, including the new element, head, and tail
    always_comb begin
        next_lsq = current_lsq;
        if (recover_enable) begin // branch recover
            if (current_lsq.head == recover_tail) begin // if all store before that branch has retired, then empty
                next_lsq.state = EMPTY; 
            end // reset all store after that branch
            for(int i=recover_tail; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
                next_lsq.entry_state[current_lsq.tail] = LSQ_STORE_INVALID;
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
                if(next_lsq.entry_state[current_lsq.tail] == LSQ_STORE_INVALID) begin //should be    
                    next_lsq.lsq_entry[current_lsq.tail] = '{default:'0};
                    next_lsq.lsq_entry[current_lsq.tail].entry_idx = current_lsq.tail;
                    next_lsq.entry_state[current_lsq.tail] = LSQ_STORE_WAITING;  // waiting for FU computation
                end
            end
            for(int i=0; i<`NUM_FU_STORE; i++) begin
                if(fu_store_enable[i]) begin // FU execute_packet update the corresponding lsq entry
                    if(next_lsq.entry_state[fu_store_packet[i].entry_idx] == LSQ_STORE_WAITING) begin //should be
                        next_lsq.lsq_entry[fu_store_packet[i].entry_idx].data = store_entry_data_block[i];
                        next_lsq.lsq_entry[fu_store_packet[i].entry_idx].block_addr = store_entry_block_addr[i];
                        next_lsq.lsq_entry[fu_store_packet[i].entry_idx].mem_size = store_entry_data_size[i];
                        next_lsq.lsq_entry[fu_store_packet[i].entry_idx].mask = get_byte_mask(fu_store_packet[i].result_value, fu_store_packet[i].mem_size);
                        next_lsq.entry_state[fu_store_packet[i].entry_idx] = LSQ_STORE_READY; 
                    end
                end // now ready, if all store before a load is ready, then the load could start to compute the mask
            end
            for(int i=0; i<retire_cnt; i++) begin // ROB retired, but lsq haven't
                if(next_lsq.entry_state[head_idx[i]] == LSQ_STORE_READY) begin // should be 
                    next_lsq.entry_state[head_idx[i]] = LSQ_STORE_RETIRED;  // after that, the head would request for dcache
                end
            end
            if(pop_cnt & (next_lsq.entry_state[current_lsq.head] == LSQ_STORE_RETIRED)) begin
                next_lsq.entry_state[current_lsq.head] = LSQ_STORE_INVALID; // this entry is already empty in lsq 
            end
            next_lsq.tail = (next_lsq.tail+store_cnt)%`LSQ_DEPTH;
            next_lsq.head = (next_lsq.head+pop_cnt)%`LSQ_DEPTH;
            next_lsq.lsq_size = next_lsq.lsq_size-pop_cnt+store_cnt;
        end
    end
    
    
    LSQ_LOAD_STATE current_load_state, next_load_state;
    logic load_can_forwarding;
    MEM_BLOCK store_data_before_load;
    BYTE_MASK store_mask_before_load;
    logic tmp_load_can_forwarding;
    MEM_BLOCK tmp_store_data_before_load;
    BYTE_MASK tmp_store_mask_before_load;
    // dcache choose load or store
    assign dcache_serve_store = (current_lsq.entry_state[current_lsq.head] == LSQ_STORE_RETIRED);
    assign dcache_serve_load = (!dcache_serve_store & (current_load_state == LSQ_LOAD_CAN_ISSUE));
    always_comb begin
        request_to_dcache_enable = 0;
        request_to_dcache_packet = 0;
        if(dcache_serve_load) begin
            //request_to_dcache_packet.block_data = ?
            request_to_dcache_packet.is_load = 1;
            request_to_dcache_packet.block_addr = load_entry_block_addr;
            request_to_dcache_packet.byte_mask = load_entry_byte_mask;
            request_to_dcache_enable = 1;
        end else if(dcache_serve_store) begin
            request_to_dcache_packet.is_load = 0;
            request_to_dcache_packet.block_data = current_lsq.lsq_entry[current_lsq.head].data;
            request_to_dcache_packet.block_addr = current_lsq.lsq_entry[current_lsq.head].block_addr;
            request_to_dcache_packet.byte_mask = current_lsq.lsq_entry[current_lsq.head].mask;
            request_to_dcache_enable = 1;
        end
    end
    always_comb begin
        next_load_state = current_load_state;
        tmp_load_can_forwarding    = load_can_forwarding;
        tmp_store_data_before_load = store_data_before_load;
        tmp_store_mask_before_load = store_mask_before_load;
        block_to_block_start = 0;
        load_result_packet = '{default: '0};
        if(recover_enable & store_cnt_before_recover_tail < store_cnt_before_load_idx) begin
            next_load_state = LSQ_LOAD_INVALID;
        end
        else begin
            case (current_load_state)
                LSQ_LOAD_INVALID: begin
                    next_load_state  = fu_load_enable ? LSQ_LOAD_WAITING : LSQ_LOAD_INVALID;
                end
                
                LSQ_LOAD_WAITING: begin
                    next_load_state  = (wait_store_before_load(fu_load_packet, current_lsq)==0) ? LSQ_LOAD_CAN_FORWARD : LSQ_LOAD_WAITING;  
                end

                LSQ_LOAD_CAN_FORWARD: begin
                    if_load_can_forward_from_store_queue(fu_load_packet, current_lsq, tmp_load_can_forwarding, tmp_store_mask_before_load, tmp_store_data_before_load);
                    if(tmp_load_can_forwarding) begin
                        load_result_packet = fu_load_packet; 
                        load_result_packet.load_block_data =  tmp_store_data_before_load; 
                        block_to_block_start = 1;  
                        next_load_state = LSQ_LOAD_COMPLETED;
                    end else begin
                        next_load_state = LSQ_LOAD_CAN_ISSUE;
                    end
                end 
                

                LSQ_LOAD_CAN_ISSUE: begin
                    if(dcache_request_valid & dcache_response_valid) begin
                        load_result_packet = fu_load_packet; 
                        load_result_packet.load_block_data = overwrite_loaddata(dcache_response.block_data, load_entry_byte_mask, store_data_before_load, store_mask_before_load);
                        block_to_block_start = 1;  
                        next_load_state = LSQ_LOAD_COMPLETED;
                    end
                end

                LSQ_LOAD_COMPLETED: begin
                    next_load_state  = load_done ? LSQ_LOAD_INVALID : LSQ_LOAD_COMPLETED;
                end

                default: next_load_state = LSQ_LOAD_INVALID;
            endcase
        end
    end

    //FSM
    always_ff@(posedge clock)begin
        if(reset) begin
            current_load_state <= 0;
            current_lsq.lsq_entry <= 0;
            current_lsq.entry_state <= 0;
            current_lsq.state <= EMPTY;
            current_lsq.head  <= 0;
            current_lsq.tail  <= 0;
            current_lsq.lsq_size <= 0;
            load_can_forwarding <= 0;
            store_mask_before_load <= 0;
            store_data_before_load <= 0;
        end else begin
            current_lsq <= next_lsq;
            current_load_state <= next_load_state;
            load_can_forwarding <= tmp_load_can_forwarding;
            store_mask_before_load <= tmp_store_mask_before_load;
            store_data_before_load <= tmp_store_data_before_load;
        end
    end


    // function
    logic wait_lsq;
    function automatic logic wait_store_before_load(input EXECUTE_PACKET load_packet, input LSQ_QUEUE current_lsq);
        
        wait_lsq = 0; 
        if(current_lsq.head == load_packet.entry_idx) begin
            return wait_lsq;   // all store before this load have retired, there's no need to wait 
        end else begin
            for (int j=current_lsq.head; j!=load_packet.entry_idx; j=(j+1)%`LSQ_DEPTH) begin
                $display("entry_state[%d]=%s",j, current_lsq.entry_state[j].name()); 
                if (current_lsq.entry_state[j]!=LSQ_STORE_READY) begin
                    $display("Need waiting"); 
                    wait_lsq = 1;
                    break;  // Exit loop early if any entry is not ready
                end
            end
        end
        return wait_lsq;
    endfunction

    BYTE_MASK mask_internal;
    MEM_BLOCK data_internal;
    BYTE_MASK load_mask;
    function automatic void if_load_can_forward_from_store_queue(input EXECUTE_PACKET fu_load_packet, input LSQ_QUEUE current_lsq, output logic load_can_forwarding, output BYTE_MASK store_mask_before_load, output MEM_BLOCK store_data_before_load);
        load_can_forwarding = 0;
        mask_internal = '0;
        data_internal = '{default:'0};
        load_mask = get_byte_mask(fu_load_packet.result_value, fu_load_packet.mem_size); 

        if(current_lsq.head < fu_load_packet.entry_idx) begin
            for(int j = current_lsq.head; j < fu_load_packet.entry_idx ; j++) begin
                if(current_lsq.lsq_entry[j].block_addr == load_entry_block_addr) begin
                    merge_byte_mask_and_data(current_lsq.lsq_entry[j].data, current_lsq.lsq_entry[j].mask, data_internal, mask_internal, data_internal, mask_internal);
                end  
            end
        // for the condition that the head is larger than the entry_idx
        end else if(current_lsq.head > fu_load_packet.entry_idx) begin
            for (int j = current_lsq.head; j != fu_load_packet.entry_idx; j=(j+1)%`LSQ_DEPTH) begin
                if(current_lsq.lsq_entry[j].block_addr == load_entry_block_addr) begin
                    merge_byte_mask_and_data(current_lsq.lsq_entry[j].data, current_lsq.lsq_entry[j].mask, data_internal, mask_internal, data_internal, mask_internal);
                end  
            end
        end
        // forwarding
        if((mask_internal & load_mask) == load_mask) begin
            load_can_forwarding = 1;
            store_data_before_load = mask_block_data(load_mask, data_internal);
            $display("fuck %b %h", load_mask, store_data_before_load); 
        // load can not forwarding then go to $D
        end else begin
            load_can_forwarding = 0;
            store_data_before_load = data_internal;
            store_mask_before_load = mask_internal;
        end
    endfunction

    function automatic MEM_BLOCK overwrite_loaddata(input MEM_BLOCK response_data, input BYTE_MASK data_byte_mask, input MEM_BLOCK store_data_before_load, input BYTE_MASK store_mask_before_load);
        MEM_BLOCK overwriten_loaddata;
        overwriten_loaddata = response_data;
        for(int i=0; i<8; i++) begin
            if(data_byte_mask[i] & store_mask_before_load[i]) begin
                overwriten_loaddata.byte_level[i] = store_data_before_load.byte_level[i];
            end
        end
        return overwriten_loaddata;
    endfunction

    always_comb begin
        current_lsq_retire_entry=0;
        current_lsq_retire_enable=0;
        for(int j=0; j<retire_cnt; j++) begin // the newest retired entry in this cycle
            current_lsq_retire_entry[j] = current_lsq.lsq_entry[head_idx[j]];
            current_lsq_retire_enable[j] = 1;
        end
    end
    assign current_lsq_dbg = current_lsq;
    assign next_lsq_dbg = next_lsq;
    assign current_load_state_dbg = current_load_state;
    assign next_load_state_dbg    = next_load_state;

    function automatic void print();
        $display("\n\n=======================================LSQ Debug Information=======================================");
        $display("\n\n-------------------------------LSQ_DISPATCH------------------------------------------");
        $display("\n\n dispatch_is_store:%b, remain:%d, current_tail:%d, full:%b empty: %b", dispatch_is_store, remain, current_tail, full, empty);
        $display("\n\n---------------------------------LSQ_FU------------------------------------------");
        $display("\n\n fu_store_enable:%b, fu_load_enable:%b", fu_store_enable, fu_load_enable);
        for(int i=0; i<`NUM_FU_STORE; i++) begin
            $display("\n\n fu_store_packet.addr:%h, fu_store_packet.data:%h", fu_store_packet[i].result_value, fu_store_packet[i].rs2_value);
        end
        $display("fu_load_packet addr: %d", fu_load_packet.result_value);
         $display("\n\n---------------------------------LSQ_ROB------------------------------------------");
        $display("\n\n ROB_retire_enable:%b, head_idx:%b, retire_cnt:%d, pop_cnt:%b", ROB_retire_enable, head_idx, retire_cnt, pop_cnt);
        $display("\n\n--------------------------------LSQ_DCACHE------------------------------------------");
        $display("\n\n dcache_request_valid:%b,dcache_response_valid:%b,request_to_dcache_enable:%b", dcache_request_valid,dcache_response_valid,request_to_dcache_enable);
        $display("\n\n dcache_serve_store:%b,dcache_serve_load:%b", dcache_serve_store,dcache_serve_load);
        $display("\n\n request_to_dcache_packet.block_addr:%h, data:%h, block_mask:%b, is_load:%b", request_to_dcache_packet.block_addr, request_to_dcache_packet.block_data, request_to_dcache_packet.byte_mask, request_to_dcache_packet.is_load);
        $display("\n\n dcache_response.block_addr:%h, data: %h", dcache_response.block_addr, dcache_response.block_data);
        $display("\n\n--------------------------------LSQ_BRANCH------------------------------------------");
        $display("\n\n recover_able:%b,recover_tail:%d",recover_enable,recover_tail);
        $display("\n\n-------------------------------LSQ_LOAD_STATE------------------------------------------");
        $display("\n\n current_load_state = %s, next_load_state = %s",current_load_state.name(),next_load_state.name());
        
        $display("tmp_store_data_before_load: %h store_data_before_load: %h", tmp_store_data_before_load, store_data_before_load); 

       $display("\n\n-------------------------------LSQ_STORE_QUEQE------------------------------------------");
        $display("current_lsq_head:%d,current_lsq_tail:%d,next_lsq_head:%d,next_lsq_tail:%d, remain:%d",current_lsq_dbg.head,current_lsq_dbg.tail,next_lsq_dbg.head,next_lsq_dbg.tail,remain);
        if(full) begin
            for(int i = 0;i<`LSQ_DEPTH;i++) begin 
                $display("current_lsq.lsq_entry[%d]:entry_idx:%d, block data: %h,state:%s",i,current_lsq.lsq_entry[(i+current_lsq.head)%`LSQ_DEPTH].entry_idx, current_lsq.lsq_entry[(i+current_lsq.head)%`LSQ_DEPTH].data,current_lsq.entry_state[(i+current_lsq.head)%`LSQ_DEPTH].name());
            end 
        end else begin 
            for(int i=current_lsq.head; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
                $display("current_lsq.lsq_entry[%d]:entry_idx:%d, block_data: %h, state:%s",i,current_lsq_dbg.lsq_entry[i].entry_idx, current_lsq_dbg.lsq_entry[i].data, current_lsq_dbg.entry_state[i].name());
            end  
        end 

        $display("---------------------------Next LSQ QUEUE--------------------"); 
        if(full) begin 
            for(int i = 0;i<`LSQ_DEPTH;i++) begin 
                $display("next_lsq.lsq_entry[%d]:entry_idx:%d, block_data: %h, state:%s",i,next_lsq.lsq_entry[(i+next_lsq.head)%`LSQ_DEPTH].entry_idx,  next_lsq.lsq_entry[(i+next_lsq.head)%`LSQ_DEPTH].data, next_lsq.entry_state[(i+next_lsq.head)%`LSQ_DEPTH].name());
            end 
        end else begin 
            for(int i=next_lsq.head; i!=current_lsq.tail; i=(i+1)%`LSQ_DEPTH) begin
                $display("next_lsq.lsq_entry[%d]:entry_idx:%d, block_data: %h, state:%s",i,next_lsq.lsq_entry[i].entry_idx,next_lsq.lsq_entry[i].data,next_lsq.entry_state[i].name());
            end 
        end 
              
        $display("\n\n--------------------------------LSQ_ELEMENT----------------------------------------");

    endfunction
endmodule
