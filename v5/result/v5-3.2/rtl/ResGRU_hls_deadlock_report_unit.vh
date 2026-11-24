   
    parameter PROC_NUM = 3;
    parameter ST_IDLE = 3'b000;
    parameter ST_FILTER_FAKE = 3'b001;
    parameter ST_DL_DETECTED = 3'b010;
    parameter ST_DL_REPORT = 3'b100;
   

    reg [2:0] CS_fsm;
    reg [2:0] NS_fsm;
    reg [PROC_NUM - 1:0] dl_detect_reg;
    reg [PROC_NUM - 1:0] dl_done_reg;
    reg [PROC_NUM - 1:0] origin_reg;
    reg [PROC_NUM - 1:0] dl_in_vec_reg;
    reg [31:0] dl_keep_cnt;
    reg stop_report_path;
    reg [PROC_NUM - 1:0] reported_proc;
    integer i;
    integer fp;

    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            reported_proc <= 'b0;
        end
        else if (CS_fsm == ST_DL_REPORT) begin
            reported_proc <= reported_proc | dl_in_vec;
        end
        else if (CS_fsm == ST_DL_DETECTED) begin
            reported_proc <= 'b0;
        end
    end

    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            stop_report_path <= 1'b0;
        end
        else if (CS_fsm == ST_DL_REPORT && (|(dl_in_vec & reported_proc))) begin
            stop_report_path <= 1'b1;
        end
        else if (CS_fsm == ST_IDLE) begin
            stop_report_path <= 1'b0;
        end
    end

    // FSM State machine
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            CS_fsm <= ST_IDLE;
        end
        else begin
            CS_fsm <= NS_fsm;
        end
    end

    always @ (CS_fsm or dl_in_vec or dl_detect_reg or dl_done_reg or dl_in_vec or origin_reg or dl_keep_cnt) begin
        case (CS_fsm)
            ST_IDLE : begin
                if (|dl_in_vec) begin
                    NS_fsm = ST_FILTER_FAKE;
                end
                else begin
                    NS_fsm = ST_IDLE;
                end
            end
            ST_FILTER_FAKE: begin
                if (dl_keep_cnt >= 32'd1000) begin
                    NS_fsm = ST_DL_DETECTED;
                end
                else if (dl_detect_reg != (dl_detect_reg & dl_in_vec)) begin
                    NS_fsm = ST_IDLE;
                end
                else begin
                    NS_fsm = ST_FILTER_FAKE;
                end
            end
            ST_DL_DETECTED: begin
                // has unreported deadlock cycle
                if ((dl_detect_reg != dl_done_reg) && stop_report_path == 1'b0) begin
                    NS_fsm = ST_DL_REPORT;
                end
                else begin
                    NS_fsm = ST_DL_DETECTED;
                end
            end
            ST_DL_REPORT: begin
                if (|(dl_in_vec & origin_reg)) begin
                    NS_fsm = ST_DL_DETECTED;
                end
                // avoid report deadlock ring.
                else if (|(dl_in_vec & reported_proc)) begin
                    NS_fsm = ST_DL_DETECTED;
                end
                else begin
                    NS_fsm = ST_DL_REPORT;
                end
            end
            default: NS_fsm = ST_IDLE;
        endcase
    end

    // dl_detect_reg record the procs that first detect deadlock
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_detect_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_IDLE) begin
                dl_detect_reg <= dl_in_vec;
            end
        end
    end

    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_keep_cnt <= 32'h0;
        end
        else begin
            if (CS_fsm == ST_FILTER_FAKE && (dl_detect_reg == (dl_detect_reg & dl_in_vec))) begin
                dl_keep_cnt <= dl_keep_cnt + 32'h1;
            end
            else if (CS_fsm == ST_FILTER_FAKE && (dl_detect_reg != (dl_detect_reg & dl_in_vec))) begin
                dl_keep_cnt <= 32'h0;
            end
        end
    end

    // dl_detect_out keeps in high after deadlock detected
    assign dl_detect_out = (|dl_detect_reg) && (CS_fsm == ST_DL_DETECTED || CS_fsm == ST_DL_REPORT);

    // dl_done_reg record the cycles has been reported
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_done_reg <= 'b0;
        end
        else begin
            if ((CS_fsm == ST_DL_REPORT) && (|(dl_in_vec & dl_detect_reg) == 'b1)) begin
                dl_done_reg <= dl_done_reg | dl_in_vec;
            end
        end
    end

    // clear token once a cycle is done
    assign token_clear = (CS_fsm == ST_DL_REPORT) ? ((|(dl_in_vec & origin_reg)) ? 'b1 : 'b0) : 'b0;

    // origin_reg record the current cycle start id
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            origin_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED) begin
                origin_reg <= origin;
            end
        end
    end
   
    // origin will be valid for only one cycle
    wire [PROC_NUM*PROC_NUM - 1:0] origin_tmp;
    assign origin_tmp[PROC_NUM - 1:0] = (dl_detect_reg[0] & ~dl_done_reg[0]) ? 'b1 : 'b0;
    genvar j;
    generate
    for(j = 1;j < PROC_NUM;j = j + 1) begin: F1
        assign origin_tmp[j*PROC_NUM +: PROC_NUM] = (dl_detect_reg[j] & ~dl_done_reg[j]) ? ('b1 << j) : origin_tmp[(j - 1)*PROC_NUM +: PROC_NUM];
    end
    endgenerate
    always @ (CS_fsm or origin_tmp) begin
        if (CS_fsm == ST_DL_DETECTED) begin
            origin = origin_tmp[(PROC_NUM - 1)*PROC_NUM +: PROC_NUM];
        end
        else begin
            origin = 'b0;
        end
    end

    
    // dl_in_vec_reg record the current cycle dl_in_vec
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_in_vec_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED) begin
                dl_in_vec_reg <= origin;
            end
            else if (CS_fsm == ST_DL_REPORT) begin
                dl_in_vec_reg <= dl_in_vec;
            end
        end
    end
    
    // find_df_deadlock to report the deadlock
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            find_df_deadlock <= 1'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED && ((dl_detect_reg == dl_done_reg) || (stop_report_path == 1'b1))) begin
                find_df_deadlock <= 1'b1;
            end
            else if (CS_fsm == ST_IDLE) begin
                find_df_deadlock <= 1'b0;
            end
        end
    end
    
    // get the first valid proc index in dl vector
    function integer proc_index(input [PROC_NUM - 1:0] dl_vec);
        begin
            proc_index = 0;
            for (i = 0; i < PROC_NUM; i = i + 1) begin
                if (dl_vec[i]) begin
                    proc_index = i;
                end
            end
        end
    endfunction

    // get the proc path based on dl vector
    function [448:0] proc_path(input [PROC_NUM - 1:0] dl_vec);
        integer index;
        begin
            index = proc_index(dl_vec);
            case (index)
                0 : begin
                    proc_path = "ResGRU_ResGRU.prepare_gates_U0";
                end
                1 : begin
                    proc_path = "ResGRU_ResGRU.Block_entry_split_split_split_proc_U0";
                end
                2 : begin
                    proc_path = "ResGRU_ResGRU.Loop_LOOP_T_proc_U0";
                end
                default : begin
                    proc_path = "unknown";
                end
            endcase
        end
    endfunction

    // print the headlines of deadlock detection
    task print_dl_head;
        begin
            $display("\n//////////////////////////////////////////////////////////////////////////////");
            $display("// ERROR!!! DEADLOCK DETECTED at %0t ns! SIMULATION WILL BE STOPPED! //", $time);
            $display("//////////////////////////////////////////////////////////////////////////////");
            fp = $fopen("deadlock_db.dat", "w");
        end
    endtask

    // print the start of a cycle
    task print_cycle_start(input reg [448:0] proc_path, input integer cycle_id);
        begin
            $display("/////////////////////////");
            $display("// Dependence cycle %0d:", cycle_id);
            $display("// (1): Process: %0s", proc_path);
            $fdisplay(fp, "Dependence_Cycle_ID %0d", cycle_id);
            $fdisplay(fp, "Dependence_Process_ID 1");
            $fdisplay(fp, "Dependence_Process_path %0s", proc_path);
        end
    endtask

    // print the end of deadlock detection
    task print_dl_end(input integer num, input integer record_time);
        begin
            $display("////////////////////////////////////////////////////////////////////////");
            $display("// Totally %0d cycles detected!", num);
            $display("////////////////////////////////////////////////////////////////////////");
            $display("// ERROR!!! DEADLOCK DETECTED at %0t ns! SIMULATION WILL BE STOPPED! //", record_time);
            $display("//////////////////////////////////////////////////////////////////////////////");
            $fdisplay(fp, "Dependence_Cycle_Number %0d", num);
            $fclose(fp);
        end
    endtask

    // print one proc component in the cycle
    task print_cycle_proc_comp(input reg [448:0] proc_path, input integer cycle_comp_id);
        begin
            $display("// (%0d): Process: %0s", cycle_comp_id, proc_path);
            $fdisplay(fp, "Dependence_Process_ID %0d", cycle_comp_id);
            $fdisplay(fp, "Dependence_Process_path %0s", proc_path);
        end
    endtask

    // print one channel component in the cycle
    task print_cycle_chan_comp(input [PROC_NUM - 1:0] dl_vec1, input [PROC_NUM - 1:0] dl_vec2);
        reg [480:0] chan_path;
        integer index1;
        integer index2;
        begin
            index1 = proc_index(dl_vec1);
            index2 = proc_index(dl_vec2);
            case (index1)
                0 : begin // for proc 'ResGRU_ResGRU.prepare_gates_U0'
                    case(index2)
                    1: begin //  for dep proc 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_prepare_gates_U0_ap_ready & ResGRU_ResGRU_inst.prepare_gates_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_Block_entry_split_split_split_proc_U0_ap_ready} input_sync}
                        if ((ap_sync_prepare_gates_U0_ap_ready & prepare_gates_U0.ap_idle & ~ap_sync_Block_entry_split_split_split_proc_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                        end
                    end
                    2: begin //  for dep proc 'ResGRU_ResGRU.Loop_LOOP_T_proc_U0'
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_prepare_gates_U0_ap_ready & ResGRU_ResGRU_inst.prepare_gates_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_Loop_LOOP_T_proc_U0_ap_ready} input_sync}
                        if ((ap_sync_prepare_gates_U0_ap_ready & prepare_gates_U0.ap_idle & ~ap_sync_Loop_LOOP_T_proc_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.Loop_LOOP_T_proc_U0'");
                        end
                    end
                    endcase
                end
                1 : begin // for proc 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'
                    case(index2)
                    0: begin //  for dep proc 'ResGRU_ResGRU.prepare_gates_U0'
// for dep channel 'ResGRU_ResGRU.r_gate_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_U.if_write} TLF_FIFO}
                        if ((~r_gate_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_U.if_write)) begin
                            if (~r_gate_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_U.if_write} TLF_FIFO}
                        if ((~z_gate_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_U.if_write)) begin
                            if (~z_gate_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_1_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_1_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_1_U.if_write} TLF_FIFO}
                        if ((~r_gate_1_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_1_U.if_write)) begin
                            if (~r_gate_1_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_1_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_1_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_1_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_1_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_1_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_1_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_1_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_1_U.if_write} TLF_FIFO}
                        if ((~z_gate_1_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_1_U.if_write)) begin
                            if (~z_gate_1_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_1_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_1_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_1_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_1_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_1_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_2_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_2_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_2_U.if_write} TLF_FIFO}
                        if ((~r_gate_2_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_2_U.if_write)) begin
                            if (~r_gate_2_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_2_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_2_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_2_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_2_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_2_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_2_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_2_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_2_U.if_write} TLF_FIFO}
                        if ((~z_gate_2_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_2_U.if_write)) begin
                            if (~z_gate_2_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_2_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_2_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_2_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_2_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_2_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_3_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_3_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_3_U.if_write} TLF_FIFO}
                        if ((~r_gate_3_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_3_U.if_write)) begin
                            if (~r_gate_3_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_3_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_3_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_3_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_3_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_3_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_3_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_3_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_3_U.if_write} TLF_FIFO}
                        if ((~z_gate_3_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_3_U.if_write)) begin
                            if (~z_gate_3_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_3_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_3_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_3_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_3_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_3_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_4_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_4_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_4_U.if_write} TLF_FIFO}
                        if ((~r_gate_4_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_4_U.if_write)) begin
                            if (~r_gate_4_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_4_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_4_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_4_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_4_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_4_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_4_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_4_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_4_U.if_write} TLF_FIFO}
                        if ((~z_gate_4_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_4_U.if_write)) begin
                            if (~z_gate_4_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_4_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_4_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_4_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_4_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_4_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_5_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_5_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_5_U.if_write} TLF_FIFO}
                        if ((~r_gate_5_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_5_U.if_write)) begin
                            if (~r_gate_5_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_5_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_5_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_5_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_5_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_5_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_5_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_5_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_5_U.if_write} TLF_FIFO}
                        if ((~z_gate_5_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_5_U.if_write)) begin
                            if (~z_gate_5_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_5_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_5_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_5_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_5_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_5_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_6_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_6_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_6_U.if_write} TLF_FIFO}
                        if ((~r_gate_6_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_6_U.if_write)) begin
                            if (~r_gate_6_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_6_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_6_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_6_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_6_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_6_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_6_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_6_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_6_U.if_write} TLF_FIFO}
                        if ((~z_gate_6_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_6_U.if_write)) begin
                            if (~z_gate_6_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_6_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_6_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_6_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_6_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_6_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_7_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_7_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_7_U.if_write} TLF_FIFO}
                        if ((~r_gate_7_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_7_U.if_write)) begin
                            if (~r_gate_7_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_7_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_7_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_7_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_7_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_7_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_7_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_7_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_7_U.if_write} TLF_FIFO}
                        if ((~z_gate_7_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_7_U.if_write)) begin
                            if (~z_gate_7_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_7_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_7_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_7_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_7_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_7_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_8_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_8_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_8_U.if_write} TLF_FIFO}
                        if ((~r_gate_8_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_8_U.if_write)) begin
                            if (~r_gate_8_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_8_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_8_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_8_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_8_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_8_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_8_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_8_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_8_U.if_write} TLF_FIFO}
                        if ((~z_gate_8_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_8_U.if_write)) begin
                            if (~z_gate_8_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_8_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_8_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_8_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_8_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_8_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_9_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_9_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_9_U.if_write} TLF_FIFO}
                        if ((~r_gate_9_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_9_U.if_write)) begin
                            if (~r_gate_9_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_9_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_9_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_9_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_9_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_9_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_9_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_9_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_9_U.if_write} TLF_FIFO}
                        if ((~z_gate_9_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_9_U.if_write)) begin
                            if (~z_gate_9_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_9_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_9_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_9_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_9_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_9_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_10_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_10_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_10_U.if_write} TLF_FIFO}
                        if ((~r_gate_10_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_10_U.if_write)) begin
                            if (~r_gate_10_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_10_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_10_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_10_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_10_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_10_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_10_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_10_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_10_U.if_write} TLF_FIFO}
                        if ((~z_gate_10_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_10_U.if_write)) begin
                            if (~z_gate_10_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_10_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_10_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_10_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_10_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_10_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_11_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_11_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_11_U.if_write} TLF_FIFO}
                        if ((~r_gate_11_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_11_U.if_write)) begin
                            if (~r_gate_11_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_11_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_11_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_11_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_11_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_11_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_11_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_11_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_11_U.if_write} TLF_FIFO}
                        if ((~z_gate_11_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_11_U.if_write)) begin
                            if (~z_gate_11_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_11_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_11_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_11_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_11_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_11_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_12_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_12_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_12_U.if_write} TLF_FIFO}
                        if ((~r_gate_12_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_12_U.if_write)) begin
                            if (~r_gate_12_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_12_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_12_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_12_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_12_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_12_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_12_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_12_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_12_U.if_write} TLF_FIFO}
                        if ((~z_gate_12_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_12_U.if_write)) begin
                            if (~z_gate_12_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_12_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_12_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_12_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_12_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_12_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_13_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_13_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_13_U.if_write} TLF_FIFO}
                        if ((~r_gate_13_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_13_U.if_write)) begin
                            if (~r_gate_13_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_13_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_13_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_13_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_13_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_13_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_13_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_13_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_13_U.if_write} TLF_FIFO}
                        if ((~z_gate_13_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_13_U.if_write)) begin
                            if (~z_gate_13_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_13_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_13_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_13_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_13_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_13_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.r_gate_14_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.r_gate_14_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.r_gate_14_U.if_write} TLF_FIFO}
                        if ((~r_gate_14_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_14_U.if_write)) begin
                            if (~r_gate_14_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.r_gate_14_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_14_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~r_gate_14_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.r_gate_14_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.r_gate_14_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_14_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_14_U.if_empty_n & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_14_U.if_write} TLF_FIFO}
                        if ((~z_gate_14_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_14_U.if_write)) begin
                            if (~z_gate_14_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_14_U' written by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_14_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_14_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_14_U' read by process 'ResGRU_ResGRU.prepare_gates_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_14_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_prepare_gates_U0_ap_ready} input_sync}
                        if ((ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & Block_entry_split_split_split_proc_U0.ap_idle & ~ap_sync_prepare_gates_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.prepare_gates_U0'");
                        end
                    end
                    2: begin //  for dep proc 'ResGRU_ResGRU.Loop_LOOP_T_proc_U0'
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & ResGRU_ResGRU_inst.Block_entry_split_split_split_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_Loop_LOOP_T_proc_U0_ap_ready} input_sync}
                        if ((ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & Block_entry_split_split_split_proc_U0.ap_idle & ~ap_sync_Loop_LOOP_T_proc_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.Loop_LOOP_T_proc_U0'");
                        end
                    end
                    endcase
                end
                2 : begin // for proc 'ResGRU_ResGRU.Loop_LOOP_T_proc_U0'
                    case(index2)
                    1: begin //  for dep proc 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_39_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_39_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_39_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_39_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_39_loc_channel_U.if_write)) begin
                            if (~sext_ln14_39_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_39_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_39_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_39_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_39_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_39_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_38_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_38_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_38_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_38_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_38_loc_channel_U.if_write)) begin
                            if (~sext_ln14_38_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_38_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_38_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_38_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_38_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_38_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_37_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_37_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_37_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_37_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_37_loc_channel_U.if_write)) begin
                            if (~sext_ln14_37_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_37_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_37_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_37_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_37_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_37_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_36_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_36_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_36_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_36_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_36_loc_channel_U.if_write)) begin
                            if (~sext_ln14_36_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_36_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_36_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_36_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_36_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_36_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_35_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_35_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_35_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_35_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_35_loc_channel_U.if_write)) begin
                            if (~sext_ln14_35_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_35_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_35_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_35_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_35_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_35_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_34_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_34_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_34_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_34_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_34_loc_channel_U.if_write)) begin
                            if (~sext_ln14_34_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_34_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_34_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_34_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_34_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_34_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_33_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_33_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_33_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_33_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_33_loc_channel_U.if_write)) begin
                            if (~sext_ln14_33_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_33_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_33_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_33_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_33_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_33_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_32_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_32_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_32_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_32_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_32_loc_channel_U.if_write)) begin
                            if (~sext_ln14_32_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_32_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_32_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_32_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_32_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_32_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_31_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_31_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_31_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_31_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_31_loc_channel_U.if_write)) begin
                            if (~sext_ln14_31_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_31_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_31_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_31_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_31_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_31_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_30_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_30_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_30_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_30_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_30_loc_channel_U.if_write)) begin
                            if (~sext_ln14_30_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_30_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_30_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_30_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_30_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_30_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln385_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln385_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln385_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln385_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_2_loc_channel_U.if_write)) begin
                            if (~sext_ln385_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln385_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln385_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln385_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_14_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_14_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_14_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_14_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_14_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_14_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_14_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_14_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_14_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_14_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_14_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_2_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_13_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_13_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_13_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_13_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_13_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_13_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_13_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_13_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_13_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_13_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_13_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_2_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_2_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_2_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_2_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_2_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_4_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_2_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_2_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_2_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_2_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_2_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_12_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_12_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_12_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_12_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_12_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_12_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_12_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_12_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_12_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_12_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_12_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_2_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_2_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_2_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_2_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_2_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_3_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_2_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_2_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_2_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_2_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_2_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_11_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_11_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_11_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_11_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_11_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_11_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_11_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_11_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_11_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_11_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_11_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_2_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_2_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_2_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_2_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_2_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_2_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_2_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_2_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_2_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_2_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_2_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_10_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_10_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_10_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_10_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_10_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_10_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_10_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_10_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_10_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_10_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_10_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_2_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_2_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_2_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_2_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_2_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_1_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_2_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_2_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_2_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_2_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_0_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_0_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_0_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_0_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_0_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_0_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_0_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_0_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_0_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_0_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_0_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_0_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_0_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_0_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_0_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_0_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_0_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_0_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_0_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_0_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_0_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_0_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_0_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_0_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_0_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_0_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_0_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_0_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_0_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_0_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_0_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_0_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_0_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_0_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_0_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_1_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_1_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_1_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_1_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_1_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_1_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_1_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_1_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_1_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_1_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_1_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_1_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_1_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_1_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_1_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_1_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_1_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_1_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_1_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_1_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_1_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_1_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_1_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_1_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_1_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_1_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_1_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_1_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_1_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_1_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_1_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_1_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_1_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_1_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_1_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_2_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_2_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_2_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_2_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_2_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_2_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_2_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_2_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_2_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_2_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_2_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_2_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_2_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_2_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_2_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_2_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_2_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_2_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_2_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_2_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_2_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_2_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_2_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_2_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_2_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_2_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_2_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_2_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_2_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_2_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_2_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_2_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_2_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_2_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_2_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_3_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_3_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_3_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_3_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_3_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_3_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_3_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_3_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_3_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_3_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_3_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_3_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_3_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_3_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_3_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_3_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_3_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_3_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_3_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_3_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_3_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_3_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_3_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_3_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_3_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_3_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_3_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_3_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_3_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_3_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_3_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_3_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_3_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_3_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_3_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_4_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_4_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_4_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_4_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_4_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_4_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_4_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_4_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_4_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_4_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_4_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_4_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_4_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_4_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_4_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_4_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_4_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_4_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_4_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_4_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_4_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_4_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_4_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_4_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_4_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_4_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_4_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_4_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_2_4_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_2_4_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_2_4_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_2_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_2_4_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_2_4_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_2_4_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_2_4_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_2_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_74_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_74_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_74_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_74_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_74_loc_channel_U.if_write)) begin
                            if (~sext_ln90_74_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_74_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_74_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_74_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_74_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_74_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_73_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_73_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_73_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_73_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_73_loc_channel_U.if_write)) begin
                            if (~sext_ln90_73_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_73_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_73_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_73_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_73_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_73_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_72_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_72_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_72_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_72_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_72_loc_channel_U.if_write)) begin
                            if (~sext_ln90_72_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_72_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_72_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_72_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_72_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_72_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_71_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_71_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_71_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_71_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_71_loc_channel_U.if_write)) begin
                            if (~sext_ln90_71_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_71_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_71_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_71_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_71_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_71_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_70_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_70_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_70_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_70_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_70_loc_channel_U.if_write)) begin
                            if (~sext_ln90_70_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_70_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_70_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_70_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_70_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_70_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_69_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_69_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_69_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_69_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_69_loc_channel_U.if_write)) begin
                            if (~sext_ln90_69_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_69_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_69_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_69_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_69_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_69_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_68_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_68_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_68_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_68_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_68_loc_channel_U.if_write)) begin
                            if (~sext_ln90_68_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_68_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_68_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_68_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_68_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_68_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_67_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_67_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_67_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_67_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_67_loc_channel_U.if_write)) begin
                            if (~sext_ln90_67_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_67_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_67_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_67_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_67_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_67_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_66_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_66_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_66_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_66_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_66_loc_channel_U.if_write)) begin
                            if (~sext_ln90_66_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_66_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_66_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_66_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_66_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_66_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_65_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_65_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_65_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_65_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_65_loc_channel_U.if_write)) begin
                            if (~sext_ln90_65_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_65_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_65_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_65_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_65_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_65_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_64_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_64_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_64_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_64_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_64_loc_channel_U.if_write)) begin
                            if (~sext_ln90_64_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_64_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_64_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_64_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_64_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_64_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_63_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_63_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_63_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_63_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_63_loc_channel_U.if_write)) begin
                            if (~sext_ln90_63_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_63_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_63_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_63_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_63_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_63_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_62_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_62_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_62_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_62_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_62_loc_channel_U.if_write)) begin
                            if (~sext_ln90_62_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_62_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_62_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_62_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_62_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_62_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_61_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_61_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_61_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_61_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_61_loc_channel_U.if_write)) begin
                            if (~sext_ln90_61_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_61_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_61_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_61_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_61_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_61_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_60_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_60_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_60_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_60_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_60_loc_channel_U.if_write)) begin
                            if (~sext_ln90_60_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_60_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_60_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_60_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_60_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_60_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_59_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_59_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_59_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_59_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_59_loc_channel_U.if_write)) begin
                            if (~sext_ln90_59_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_59_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_59_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_59_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_59_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_59_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_58_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_58_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_58_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_58_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_58_loc_channel_U.if_write)) begin
                            if (~sext_ln90_58_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_58_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_58_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_58_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_58_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_58_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_57_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_57_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_57_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_57_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_57_loc_channel_U.if_write)) begin
                            if (~sext_ln90_57_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_57_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_57_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_57_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_57_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_57_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_56_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_56_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_56_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_56_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_56_loc_channel_U.if_write)) begin
                            if (~sext_ln90_56_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_56_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_56_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_56_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_56_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_56_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_55_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_55_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_55_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_55_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_55_loc_channel_U.if_write)) begin
                            if (~sext_ln90_55_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_55_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_55_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_55_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_55_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_55_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_54_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_54_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_54_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_54_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_54_loc_channel_U.if_write)) begin
                            if (~sext_ln90_54_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_54_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_54_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_54_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_54_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_54_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_53_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_53_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_53_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_53_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_53_loc_channel_U.if_write)) begin
                            if (~sext_ln90_53_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_53_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_53_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_53_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_53_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_53_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_52_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_52_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_52_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_52_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_52_loc_channel_U.if_write)) begin
                            if (~sext_ln90_52_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_52_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_52_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_52_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_52_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_52_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_51_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_51_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_51_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_51_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_51_loc_channel_U.if_write)) begin
                            if (~sext_ln90_51_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_51_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_51_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_51_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_51_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_51_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_50_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_50_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_50_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_50_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_50_loc_channel_U.if_write)) begin
                            if (~sext_ln90_50_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_50_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_50_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_50_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_50_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_50_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln385_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln385_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln385_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln385_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_1_loc_channel_U.if_write)) begin
                            if (~sext_ln385_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln385_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln385_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln385_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_9_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_9_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_9_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_9_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_9_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_9_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_9_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_9_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_9_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_9_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_9_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_1_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_8_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_8_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_8_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_8_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_8_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_8_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_8_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_8_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_8_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_8_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_8_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_1_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_1_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_1_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_1_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_1_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_4_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_1_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_1_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_1_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_1_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_1_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_7_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_7_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_7_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_7_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_7_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_7_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_7_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_7_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_7_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_7_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_7_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_1_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_1_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_1_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_1_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_1_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_3_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_1_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_1_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_1_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_1_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_1_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_6_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_6_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_6_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_6_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_6_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_6_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_6_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_6_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_6_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_6_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_6_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_1_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_1_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_1_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_1_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_1_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_2_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_1_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_1_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_1_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_1_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_1_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_5_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_5_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_5_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_5_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_5_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_5_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_5_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_5_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_5_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_5_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_5_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_1_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_1_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_1_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_1_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_1_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_1_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_1_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_1_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_1_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_1_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_0_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_0_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_0_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_0_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_0_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_0_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_0_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_0_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_0_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_0_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_0_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_0_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_0_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_0_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_0_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_0_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_0_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_0_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_0_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_0_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_0_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_0_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_0_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_0_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_0_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_0_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_0_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_0_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_0_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_0_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_0_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_0_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_0_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_0_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_0_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_1_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_1_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_1_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_1_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_1_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_1_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_1_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_1_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_1_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_1_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_1_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_1_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_1_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_1_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_1_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_1_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_1_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_1_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_1_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_1_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_1_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_1_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_1_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_1_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_1_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_1_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_1_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_1_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_1_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_1_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_1_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_1_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_1_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_1_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_1_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_2_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_2_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_2_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_2_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_2_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_2_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_2_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_2_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_2_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_2_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_2_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_2_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_2_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_2_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_2_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_2_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_2_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_2_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_2_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_2_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_2_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_2_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_2_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_2_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_2_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_2_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_2_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_2_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_2_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_2_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_2_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_2_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_2_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_2_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_2_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_3_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_3_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_3_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_3_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_3_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_3_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_3_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_3_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_3_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_3_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_3_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_3_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_3_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_3_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_3_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_3_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_3_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_3_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_3_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_3_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_3_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_3_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_3_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_3_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_3_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_3_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_3_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_3_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_3_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_3_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_3_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_3_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_3_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_3_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_3_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_4_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_4_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_4_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_4_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_4_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_4_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_4_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_4_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_4_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_4_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_4_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_4_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_4_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_4_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_4_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_4_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_4_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_4_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_4_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_4_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_4_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_4_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_4_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_4_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_4_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_4_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_4_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_4_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_1_4_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_1_4_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_1_4_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_1_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_1_4_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_1_4_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_1_4_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_1_4_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_1_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_49_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_49_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_49_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_49_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_49_loc_channel_U.if_write)) begin
                            if (~sext_ln90_49_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_49_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_49_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_49_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_49_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_49_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_48_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_48_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_48_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_48_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_48_loc_channel_U.if_write)) begin
                            if (~sext_ln90_48_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_48_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_48_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_48_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_48_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_48_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_47_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_47_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_47_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_47_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_47_loc_channel_U.if_write)) begin
                            if (~sext_ln90_47_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_47_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_47_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_47_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_47_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_47_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_46_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_46_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_46_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_46_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_46_loc_channel_U.if_write)) begin
                            if (~sext_ln90_46_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_46_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_46_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_46_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_46_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_46_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_45_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_45_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_45_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_45_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_45_loc_channel_U.if_write)) begin
                            if (~sext_ln90_45_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_45_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_45_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_45_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_45_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_45_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_44_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_44_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_44_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_44_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_44_loc_channel_U.if_write)) begin
                            if (~sext_ln90_44_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_44_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_44_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_44_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_44_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_44_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_43_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_43_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_43_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_43_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_43_loc_channel_U.if_write)) begin
                            if (~sext_ln90_43_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_43_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_43_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_43_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_43_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_43_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_42_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_42_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_42_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_42_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_42_loc_channel_U.if_write)) begin
                            if (~sext_ln90_42_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_42_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_42_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_42_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_42_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_42_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_41_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_41_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_41_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_41_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_41_loc_channel_U.if_write)) begin
                            if (~sext_ln90_41_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_41_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_41_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_41_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_41_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_41_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_40_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_40_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_40_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_40_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_40_loc_channel_U.if_write)) begin
                            if (~sext_ln90_40_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_40_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_40_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_40_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_40_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_40_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_39_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_39_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_39_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_39_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_39_loc_channel_U.if_write)) begin
                            if (~sext_ln90_39_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_39_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_39_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_39_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_39_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_39_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_38_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_38_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_38_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_38_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_38_loc_channel_U.if_write)) begin
                            if (~sext_ln90_38_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_38_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_38_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_38_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_38_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_38_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_37_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_37_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_37_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_37_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_37_loc_channel_U.if_write)) begin
                            if (~sext_ln90_37_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_37_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_37_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_37_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_37_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_37_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_36_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_36_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_36_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_36_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_36_loc_channel_U.if_write)) begin
                            if (~sext_ln90_36_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_36_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_36_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_36_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_36_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_36_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_35_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_35_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_35_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_35_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_35_loc_channel_U.if_write)) begin
                            if (~sext_ln90_35_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_35_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_35_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_35_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_35_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_35_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_34_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_34_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_34_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_34_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_34_loc_channel_U.if_write)) begin
                            if (~sext_ln90_34_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_34_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_34_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_34_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_34_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_34_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_33_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_33_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_33_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_33_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_33_loc_channel_U.if_write)) begin
                            if (~sext_ln90_33_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_33_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_33_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_33_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_33_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_33_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_32_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_32_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_32_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_32_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_32_loc_channel_U.if_write)) begin
                            if (~sext_ln90_32_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_32_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_32_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_32_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_32_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_32_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_31_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_31_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_31_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_31_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_31_loc_channel_U.if_write)) begin
                            if (~sext_ln90_31_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_31_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_31_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_31_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_31_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_31_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_30_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_30_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_30_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_30_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_30_loc_channel_U.if_write)) begin
                            if (~sext_ln90_30_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_30_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_30_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_30_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_30_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_30_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_29_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_29_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_29_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_29_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_29_loc_channel_U.if_write)) begin
                            if (~sext_ln90_29_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_29_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_29_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_29_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_29_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_29_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_28_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_28_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_28_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_28_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_28_loc_channel_U.if_write)) begin
                            if (~sext_ln90_28_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_28_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_28_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_28_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_28_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_28_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_27_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_27_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_27_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_27_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_27_loc_channel_U.if_write)) begin
                            if (~sext_ln90_27_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_27_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_27_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_27_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_27_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_27_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_26_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_26_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_26_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_26_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_26_loc_channel_U.if_write)) begin
                            if (~sext_ln90_26_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_26_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_26_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_26_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_26_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_26_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_25_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_25_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_25_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_25_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_25_loc_channel_U.if_write)) begin
                            if (~sext_ln90_25_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_25_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_25_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_25_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_25_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_25_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln385_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln385_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln385_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln385_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_loc_channel_U.if_write)) begin
                            if (~sext_ln385_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln385_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln385_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln385_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln385_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_4_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_4_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_4_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_4_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_4_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_4_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_4_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_4_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_4_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_4_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_4_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_3_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_3_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_3_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_3_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_3_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_3_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_3_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_3_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_3_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_3_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_3_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_4_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_4_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_2_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_2_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_2_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_2_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_2_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_2_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_2_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_2_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_2_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_2_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_2_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_3_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_3_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_21855_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_21855_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_21855_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_21855_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_21855_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_21855_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_21855_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_1_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_1_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_1_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_1_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_1_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_1_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_1_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_1_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_1_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_1_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_1_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_21770_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_21770_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_21770_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_21770_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_21770_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_21770_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_21770_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_21781_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_21781_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_21781_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_21781_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_21781_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_21781_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_21781_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_21781_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_21781_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_21781_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_21781_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_11612_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_11612_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_11612_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_11612_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_11612_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_11612_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_11612_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.z_gate_load_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.z_gate_load_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.z_gate_load_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~z_gate_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_load_cast_loc_channel_U.if_write)) begin
                            if (~z_gate_load_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.z_gate_load_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~z_gate_load_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.z_gate_load_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.z_gate_load_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_11527_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_11527_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_11527_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_11527_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_11527_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_11527_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_11527_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_11538_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_11538_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_11538_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_11538_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_11538_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_11538_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_11538_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_11538_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_11538_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_11538_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_11538_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i261_i_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i261_i_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i261_i_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i261_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i261_i_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i261_i_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i261_i_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i261_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_0_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_0_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_0_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_0_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_0_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_0_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_0_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_0_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_0_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_0_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_0_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_0_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_0_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_0_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_0_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_0_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_0_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_0_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_0_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_0_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_0_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_0_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_0_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_0_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_0_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_0_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_0_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_0_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_0_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_0_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_0_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_0_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_0_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_0_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_0_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_0_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_1_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_1_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_1_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_1_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_1_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_1_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_1_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_1_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_1_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_1_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_1_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_1_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_1_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_1_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_1_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_1_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_1_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_1_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_1_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_1_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_1_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_1_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_1_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_1_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_1_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_1_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_1_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_1_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_1_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_1_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_1_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_1_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_1_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_1_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_1_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_1_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_2_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_2_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_2_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_2_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_2_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_2_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_2_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_2_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_2_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_2_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_2_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_2_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_2_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_2_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_2_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_2_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_2_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_2_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_2_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_2_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_2_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_2_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_2_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_2_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_2_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_2_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_2_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_2_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_2_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_2_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_2_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_2_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_2_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_2_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_2_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_2_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_3_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_3_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_3_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_3_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_3_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_3_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_3_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_3_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_3_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_3_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_3_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_3_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_3_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_3_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_3_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_3_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_3_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_3_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_3_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_3_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_3_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_3_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_3_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_3_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_3_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_3_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_3_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_3_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_3_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_3_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_3_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_3_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_3_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_3_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_3_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_3_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_4_0_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_4_0_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_4_0_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_0_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_4_0_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_4_0_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_4_0_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_4_0_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_0_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_4_1_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_4_1_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_4_1_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_1_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_4_1_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_4_1_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_4_1_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_4_1_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_1_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_4_2_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_4_2_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_4_2_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_2_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_4_2_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_4_2_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_4_2_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_4_2_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_2_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_4_3_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_4_3_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_4_3_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_3_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_4_3_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_4_3_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_4_3_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_4_3_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_3_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.W_hn_0_4_4_load_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.W_hn_0_4_4_load_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.W_hn_0_4_4_load_loc_channel_U.if_write} TLF_FIFO}
                        if ((~W_hn_0_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_4_load_loc_channel_U.if_write)) begin
                            if (~W_hn_0_4_4_load_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.W_hn_0_4_4_load_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~W_hn_0_4_4_load_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.W_hn_0_4_4_load_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.W_hn_0_4_4_load_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.shl_i_i18_i409_i_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.shl_i_i18_i409_i_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.shl_i_i18_i409_i_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~shl_i_i18_i409_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_cast_loc_channel_U.if_write)) begin
                            if (~shl_i_i18_i409_i_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~shl_i_i18_i409_i_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.shl_i_i18_i409_i_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.shl_i_i18_i409_i_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv_i357_i_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv_i357_i_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv_i357_i_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv_i357_i_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_loc_channel_U.if_write)) begin
                            if (~conv_i357_i_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv_i357_i_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv_i357_i_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv_i357_i_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv_i357_i_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_24_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_24_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_24_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_24_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_24_loc_channel_U.if_write)) begin
                            if (~sext_ln90_24_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_24_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_24_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_24_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_24_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_24_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_23_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_23_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_23_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_23_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_23_loc_channel_U.if_write)) begin
                            if (~sext_ln90_23_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_23_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_23_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_23_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_23_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_23_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_22_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_22_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_22_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_22_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_22_loc_channel_U.if_write)) begin
                            if (~sext_ln90_22_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_22_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_22_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_22_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_22_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_22_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_21_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_21_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_21_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_21_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_21_loc_channel_U.if_write)) begin
                            if (~sext_ln90_21_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_21_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_21_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_21_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_21_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_21_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_20_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_20_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_20_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_20_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_20_loc_channel_U.if_write)) begin
                            if (~sext_ln90_20_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_20_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_20_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_20_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_20_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_20_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_19_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_19_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_19_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_19_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_19_loc_channel_U.if_write)) begin
                            if (~sext_ln90_19_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_19_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_19_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_19_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_19_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_19_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_18_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_18_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_18_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_18_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_18_loc_channel_U.if_write)) begin
                            if (~sext_ln90_18_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_18_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_18_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_18_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_18_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_18_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_17_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_17_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_17_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_17_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_17_loc_channel_U.if_write)) begin
                            if (~sext_ln90_17_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_17_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_17_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_17_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_17_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_17_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_16_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_16_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_16_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_16_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_16_loc_channel_U.if_write)) begin
                            if (~sext_ln90_16_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_16_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_16_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_16_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_16_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_16_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_15_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_15_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_15_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_15_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_15_loc_channel_U.if_write)) begin
                            if (~sext_ln90_15_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_15_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_15_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_15_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_15_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_15_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_14_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_14_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_14_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_14_loc_channel_U.if_write)) begin
                            if (~sext_ln90_14_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_14_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_14_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_14_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_13_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_13_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_13_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_13_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_13_loc_channel_U.if_write)) begin
                            if (~sext_ln90_13_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_13_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_13_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_13_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_13_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_13_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_12_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_12_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_12_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_12_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_12_loc_channel_U.if_write)) begin
                            if (~sext_ln90_12_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_12_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_12_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_12_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_12_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_12_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_11_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_11_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_11_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_11_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_11_loc_channel_U.if_write)) begin
                            if (~sext_ln90_11_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_11_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_11_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_11_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_11_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_11_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_10_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_10_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_10_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_10_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_10_loc_channel_U.if_write)) begin
                            if (~sext_ln90_10_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_10_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_10_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_10_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_10_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_10_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_9_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_9_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_9_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_9_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_9_loc_channel_U.if_write)) begin
                            if (~sext_ln90_9_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_9_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_9_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_9_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_9_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_9_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_8_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_8_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_8_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_8_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_8_loc_channel_U.if_write)) begin
                            if (~sext_ln90_8_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_8_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_8_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_8_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_8_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_8_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_7_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_7_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_7_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_7_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_7_loc_channel_U.if_write)) begin
                            if (~sext_ln90_7_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_7_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_7_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_7_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_7_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_7_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_6_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_6_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_6_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_6_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_6_loc_channel_U.if_write)) begin
                            if (~sext_ln90_6_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_6_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_6_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_6_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_6_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_6_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_5_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_5_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_5_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_5_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_5_loc_channel_U.if_write)) begin
                            if (~sext_ln90_5_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_5_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_5_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_5_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_5_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_5_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_4_loc_channel_U.if_write)) begin
                            if (~sext_ln90_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_3_loc_channel_U.if_write)) begin
                            if (~sext_ln90_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_2_loc_channel_U.if_write)) begin
                            if (~sext_ln90_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_1_loc_channel_U.if_write)) begin
                            if (~sext_ln90_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln90_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln90_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln90_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln90_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_loc_channel_U.if_write)) begin
                            if (~sext_ln90_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln90_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln90_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln90_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln90_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.conv7_i_i844_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.conv7_i_i844_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.conv7_i_i844_loc_channel_U.if_write} TLF_FIFO}
                        if ((~conv7_i_i844_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv7_i_i844_loc_channel_U.if_write)) begin
                            if (~conv7_i_i844_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.conv7_i_i844_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv7_i_i844_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~conv7_i_i844_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.conv7_i_i844_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.conv7_i_i844_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_4_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_4_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_4_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_4_cast_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_4_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_4_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_4_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_4_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_4_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_4_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_29_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_29_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_29_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_29_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_29_loc_channel_U.if_write)) begin
                            if (~sext_ln14_29_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_29_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_29_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_29_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_29_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_29_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_28_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_28_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_28_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_28_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_28_loc_channel_U.if_write)) begin
                            if (~sext_ln14_28_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_28_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_28_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_28_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_28_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_28_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_27_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_27_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_27_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_27_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_27_loc_channel_U.if_write)) begin
                            if (~sext_ln14_27_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_27_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_27_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_27_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_27_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_27_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_26_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_26_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_26_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_26_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_26_loc_channel_U.if_write)) begin
                            if (~sext_ln14_26_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_26_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_26_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_26_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_26_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_26_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_25_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_25_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_25_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_25_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_25_loc_channel_U.if_write)) begin
                            if (~sext_ln14_25_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_25_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_25_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_25_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_25_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_25_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_3_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_3_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_3_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_3_cast_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_3_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_3_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_3_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_3_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_3_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_3_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_24_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_24_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_24_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_24_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_24_loc_channel_U.if_write)) begin
                            if (~sext_ln14_24_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_24_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_24_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_24_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_24_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_24_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_23_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_23_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_23_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_23_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_23_loc_channel_U.if_write)) begin
                            if (~sext_ln14_23_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_23_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_23_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_23_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_23_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_23_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_22_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_22_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_22_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_22_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_22_loc_channel_U.if_write)) begin
                            if (~sext_ln14_22_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_22_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_22_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_22_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_22_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_22_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_21_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_21_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_21_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_21_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_21_loc_channel_U.if_write)) begin
                            if (~sext_ln14_21_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_21_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_21_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_21_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_21_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_21_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_20_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_20_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_20_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_20_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_20_loc_channel_U.if_write)) begin
                            if (~sext_ln14_20_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_20_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_20_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_20_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_20_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_20_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_19_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_19_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_19_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_19_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_19_loc_channel_U.if_write)) begin
                            if (~sext_ln14_19_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_19_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_19_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_19_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_19_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_19_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_2_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_2_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_2_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_2_cast_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_2_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_2_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_2_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_2_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_2_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_2_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_18_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_18_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_18_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_18_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_18_loc_channel_U.if_write)) begin
                            if (~sext_ln14_18_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_18_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_18_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_18_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_18_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_18_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_17_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_17_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_17_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_17_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_17_loc_channel_U.if_write)) begin
                            if (~sext_ln14_17_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_17_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_17_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_17_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_17_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_17_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_16_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_16_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_16_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_16_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_16_loc_channel_U.if_write)) begin
                            if (~sext_ln14_16_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_16_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_16_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_16_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_16_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_16_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_15_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_15_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_15_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_15_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_15_loc_channel_U.if_write)) begin
                            if (~sext_ln14_15_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_15_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_15_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_15_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_15_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_15_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_14_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_14_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_14_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_14_loc_channel_U.if_write)) begin
                            if (~sext_ln14_14_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_14_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_14_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_14_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_13_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_13_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_13_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_13_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_13_loc_channel_U.if_write)) begin
                            if (~sext_ln14_13_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_13_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_13_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_13_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_13_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_13_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_1_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_1_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_1_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_1_cast_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_1_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_1_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_1_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_1_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_1_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_1_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_12_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_12_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_12_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_12_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_12_loc_channel_U.if_write)) begin
                            if (~sext_ln14_12_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_12_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_12_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_12_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_12_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_12_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_11_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_11_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_11_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_11_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_11_loc_channel_U.if_write)) begin
                            if (~sext_ln14_11_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_11_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_11_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_11_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_11_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_11_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_10_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_10_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_10_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_10_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_10_loc_channel_U.if_write)) begin
                            if (~sext_ln14_10_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_10_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_10_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_10_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_10_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_10_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_9_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_9_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_9_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_9_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_9_loc_channel_U.if_write)) begin
                            if (~sext_ln14_9_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_9_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_9_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_9_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_9_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_9_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_8_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_8_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_8_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_8_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_8_loc_channel_U.if_write)) begin
                            if (~sext_ln14_8_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_8_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_8_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_8_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_8_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_8_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_7_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_7_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_7_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_7_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_7_loc_channel_U.if_write)) begin
                            if (~sext_ln14_7_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_7_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_7_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_7_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_7_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_7_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_cast_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_cast_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_cast_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_cast_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_cast_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_cast_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_cast_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_cast_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_cast_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.trunc_ln46_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.trunc_ln46_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.trunc_ln46_loc_channel_U.if_write} TLF_FIFO}
                        if ((~trunc_ln46_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_loc_channel_U.if_write)) begin
                            if (~trunc_ln46_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.trunc_ln46_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~trunc_ln46_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.trunc_ln46_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.trunc_ln46_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_6_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_6_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_6_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_6_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_6_loc_channel_U.if_write)) begin
                            if (~sext_ln14_6_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_6_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_6_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_6_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_6_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_6_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_5_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_5_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_5_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_5_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_5_loc_channel_U.if_write)) begin
                            if (~sext_ln14_5_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_5_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_5_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_5_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_5_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_5_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_4_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_4_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_4_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_4_loc_channel_U.if_write)) begin
                            if (~sext_ln14_4_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_4_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_4_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_4_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_4_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_3_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_3_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_3_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_3_loc_channel_U.if_write)) begin
                            if (~sext_ln14_3_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_3_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_3_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_3_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_3_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_2_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_2_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_2_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_2_loc_channel_U.if_write)) begin
                            if (~sext_ln14_2_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_2_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_2_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_2_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_2_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_1_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_1_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_1_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_1_loc_channel_U.if_write)) begin
                            if (~sext_ln14_1_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_1_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_1_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_1_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_1_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel 'ResGRU_ResGRU.sext_ln14_loc_channel_U' info is :
// blk sig is {{~ResGRU_ResGRU_inst.sext_ln14_loc_channel_U.if_empty_n & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.sext_ln14_loc_channel_U.if_write} TLF_FIFO}
                        if ((~sext_ln14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_loc_channel_U.if_write)) begin
                            if (~sext_ln14_loc_channel_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'ResGRU_ResGRU.sext_ln14_loc_channel_U' written by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~sext_ln14_loc_channel_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'ResGRU_ResGRU.sext_ln14_loc_channel_U' read by process 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                                $fdisplay(fp, "Dependence_Channel_path ResGRU_ResGRU.sext_ln14_loc_channel_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_Loop_LOOP_T_proc_U0_ap_ready & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_Block_entry_split_split_split_proc_U0_ap_ready} input_sync}
                        if ((ap_sync_Loop_LOOP_T_proc_U0_ap_ready & Loop_LOOP_T_proc_U0.ap_idle & ~ap_sync_Block_entry_split_split_split_proc_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.Block_entry_split_split_split_proc_U0'");
                        end
                    end
                    0: begin //  for dep proc 'ResGRU_ResGRU.prepare_gates_U0'
// for dep channel '' info is :
// blk sig is {{ResGRU_ResGRU_inst.ap_sync_Loop_LOOP_T_proc_U0_ap_ready & ResGRU_ResGRU_inst.Loop_LOOP_T_proc_U0.ap_idle & ~ResGRU_ResGRU_inst.ap_sync_prepare_gates_U0_ap_ready} input_sync}
                        if ((ap_sync_Loop_LOOP_T_proc_U0_ap_ready & Loop_LOOP_T_proc_U0.ap_idle & ~ap_sync_prepare_gates_U0_ap_ready)) begin
                            $display("//      Blocked by input sync logic with process : 'ResGRU_ResGRU.prepare_gates_U0'");
                        end
                    end
                    endcase
                end
            endcase
        end
    endtask

    // report
    initial begin : report_deadlock
        integer cycle_id;
        integer cycle_comp_id;
        integer record_time;
        wait (dl_reset == 1);
        cycle_id = 1;
        record_time = 0;
        while (1) begin
            @ (negedge dl_clock);
            case (CS_fsm)
                ST_DL_DETECTED: begin
                    cycle_comp_id = 2;
                    if (dl_detect_reg != dl_done_reg && stop_report_path == 1'b0) begin
                        if (dl_done_reg == 'b0) begin
                            print_dl_head;
                            record_time = $time;
                        end
                        print_cycle_start(proc_path(origin), cycle_id);
                        cycle_id = cycle_id + 1;
                    end
                    else begin
                        print_dl_end((cycle_id - 1),record_time);
                        @(negedge dl_clock);
                        @(negedge dl_clock);
                        $finish;
                    end
                end
                ST_DL_REPORT: begin
                    if ((|(dl_in_vec)) & ~(|(dl_in_vec & origin_reg)) & ~(|(reported_proc & dl_in_vec))) begin
                        print_cycle_chan_comp(dl_in_vec_reg, dl_in_vec);
                        print_cycle_proc_comp(proc_path(dl_in_vec), cycle_comp_id);
                        cycle_comp_id = cycle_comp_id + 1;
                    end
                    else if (~(|(dl_in_vec)))begin
                        print_cycle_chan_comp(dl_in_vec_reg, dl_in_vec);
                    end
                end
            endcase
        end
    end
 
