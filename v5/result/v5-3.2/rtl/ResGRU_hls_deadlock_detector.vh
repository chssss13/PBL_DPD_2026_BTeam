
    wire dl_reset;
    wire dl_clock;
    assign dl_reset = ~ap_rst;
    assign dl_clock = ap_clk;
    wire [1:0] proc_0_data_FIFO_blk;
    wire [1:0] proc_0_data_PIPO_blk;
    wire [1:0] proc_0_start_FIFO_blk;
    wire [1:0] proc_0_TLF_FIFO_blk;
    wire [1:0] proc_0_input_sync_blk;
    wire [1:0] proc_0_output_sync_blk;
    wire [1:0] proc_dep_vld_vec_0;
    reg [1:0] proc_dep_vld_vec_0_reg;
    wire [1:0] in_chan_dep_vld_vec_0;
    wire [5:0] in_chan_dep_data_vec_0;
    wire [1:0] token_in_vec_0;
    wire [1:0] out_chan_dep_vld_vec_0;
    wire [2:0] out_chan_dep_data_0;
    wire [1:0] token_out_vec_0;
    wire dl_detect_out_0;
    wire dep_chan_vld_1_0;
    wire [2:0] dep_chan_data_1_0;
    wire token_1_0;
    wire dep_chan_vld_2_0;
    wire [2:0] dep_chan_data_2_0;
    wire token_2_0;
    wire [1:0] proc_1_data_FIFO_blk;
    wire [1:0] proc_1_data_PIPO_blk;
    wire [1:0] proc_1_start_FIFO_blk;
    wire [1:0] proc_1_TLF_FIFO_blk;
    wire [1:0] proc_1_input_sync_blk;
    wire [1:0] proc_1_output_sync_blk;
    wire [1:0] proc_dep_vld_vec_1;
    reg [1:0] proc_dep_vld_vec_1_reg;
    wire [1:0] in_chan_dep_vld_vec_1;
    wire [5:0] in_chan_dep_data_vec_1;
    wire [1:0] token_in_vec_1;
    wire [1:0] out_chan_dep_vld_vec_1;
    wire [2:0] out_chan_dep_data_1;
    wire [1:0] token_out_vec_1;
    wire dl_detect_out_1;
    wire dep_chan_vld_0_1;
    wire [2:0] dep_chan_data_0_1;
    wire token_0_1;
    wire dep_chan_vld_2_1;
    wire [2:0] dep_chan_data_2_1;
    wire token_2_1;
    wire [1:0] proc_2_data_FIFO_blk;
    wire [1:0] proc_2_data_PIPO_blk;
    wire [1:0] proc_2_start_FIFO_blk;
    wire [1:0] proc_2_TLF_FIFO_blk;
    wire [1:0] proc_2_input_sync_blk;
    wire [1:0] proc_2_output_sync_blk;
    wire [1:0] proc_dep_vld_vec_2;
    reg [1:0] proc_dep_vld_vec_2_reg;
    wire [1:0] in_chan_dep_vld_vec_2;
    wire [5:0] in_chan_dep_data_vec_2;
    wire [1:0] token_in_vec_2;
    wire [1:0] out_chan_dep_vld_vec_2;
    wire [2:0] out_chan_dep_data_2;
    wire [1:0] token_out_vec_2;
    wire dl_detect_out_2;
    wire dep_chan_vld_0_2;
    wire [2:0] dep_chan_data_0_2;
    wire token_0_2;
    wire dep_chan_vld_1_2;
    wire [2:0] dep_chan_data_1_2;
    wire token_1_2;
    wire [2:0] dl_in_vec;
    wire dl_detect_out;
    wire token_clear;
    reg [2:0] origin;

    reg ap_done_reg_0;// for module Block_entry_split_split_split_proc_U0
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            ap_done_reg_0 <= 'b0;
        end
        else begin
            ap_done_reg_0 <= Block_entry_split_split_split_proc_U0.ap_done & ~Block_entry_split_split_split_proc_U0.ap_continue;
        end
    end

    reg ap_done_reg_1;// for module Loop_LOOP_T_proc_U0
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            ap_done_reg_1 <= 'b0;
        end
        else begin
            ap_done_reg_1 <= Loop_LOOP_T_proc_U0.ap_done & ~Loop_LOOP_T_proc_U0.ap_continue;
        end
    end

    // Process: prepare_gates_U0
    ResGRU_hls_deadlock_detect_unit #(3, 0, 2, 2) ResGRU_hls_deadlock_detect_unit_0 (
        .reset(dl_reset),
        .clock(dl_clock),
        .proc_dep_vld_vec(proc_dep_vld_vec_0),
        .in_chan_dep_vld_vec(in_chan_dep_vld_vec_0),
        .in_chan_dep_data_vec(in_chan_dep_data_vec_0),
        .token_in_vec(token_in_vec_0),
        .dl_detect_in(dl_detect_out),
        .origin(origin[0]),
        .token_clear(token_clear),
        .out_chan_dep_vld_vec(out_chan_dep_vld_vec_0),
        .out_chan_dep_data(out_chan_dep_data_0),
        .token_out_vec(token_out_vec_0),
        .dl_detect_out(dl_in_vec[0]));

    assign proc_0_data_FIFO_blk[0] = 1'b0;
    assign proc_0_data_PIPO_blk[0] = 1'b0;
    assign proc_0_start_FIFO_blk[0] = 1'b0;
    assign proc_0_TLF_FIFO_blk[0] = 1'b0;
    assign proc_0_input_sync_blk[0] = 1'b0 | (ap_sync_prepare_gates_U0_ap_ready & prepare_gates_U0.ap_idle & ~ap_sync_Block_entry_split_split_split_proc_U0_ap_ready);
    assign proc_0_output_sync_blk[0] = 1'b0;
    assign proc_dep_vld_vec_0[0] = dl_detect_out ? proc_dep_vld_vec_0_reg[0] : (proc_0_data_FIFO_blk[0] | proc_0_data_PIPO_blk[0] | proc_0_start_FIFO_blk[0] | proc_0_TLF_FIFO_blk[0] | proc_0_input_sync_blk[0] | proc_0_output_sync_blk[0]);
    assign proc_0_data_FIFO_blk[1] = 1'b0;
    assign proc_0_data_PIPO_blk[1] = 1'b0;
    assign proc_0_start_FIFO_blk[1] = 1'b0;
    assign proc_0_TLF_FIFO_blk[1] = 1'b0;
    assign proc_0_input_sync_blk[1] = 1'b0 | (ap_sync_prepare_gates_U0_ap_ready & prepare_gates_U0.ap_idle & ~ap_sync_Loop_LOOP_T_proc_U0_ap_ready);
    assign proc_0_output_sync_blk[1] = 1'b0;
    assign proc_dep_vld_vec_0[1] = dl_detect_out ? proc_dep_vld_vec_0_reg[1] : (proc_0_data_FIFO_blk[1] | proc_0_data_PIPO_blk[1] | proc_0_start_FIFO_blk[1] | proc_0_TLF_FIFO_blk[1] | proc_0_input_sync_blk[1] | proc_0_output_sync_blk[1]);
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            proc_dep_vld_vec_0_reg <= 'b0;
        end
        else begin
            proc_dep_vld_vec_0_reg <= proc_dep_vld_vec_0;
        end
    end
    assign in_chan_dep_vld_vec_0[0] = dep_chan_vld_1_0;
    assign in_chan_dep_data_vec_0[2 : 0] = dep_chan_data_1_0;
    assign token_in_vec_0[0] = token_1_0;
    assign in_chan_dep_vld_vec_0[1] = dep_chan_vld_2_0;
    assign in_chan_dep_data_vec_0[5 : 3] = dep_chan_data_2_0;
    assign token_in_vec_0[1] = token_2_0;
    assign dep_chan_vld_0_1 = out_chan_dep_vld_vec_0[0];
    assign dep_chan_data_0_1 = out_chan_dep_data_0;
    assign token_0_1 = token_out_vec_0[0];
    assign dep_chan_vld_0_2 = out_chan_dep_vld_vec_0[1];
    assign dep_chan_data_0_2 = out_chan_dep_data_0;
    assign token_0_2 = token_out_vec_0[1];

    // Process: Block_entry_split_split_split_proc_U0
    ResGRU_hls_deadlock_detect_unit #(3, 1, 2, 2) ResGRU_hls_deadlock_detect_unit_1 (
        .reset(dl_reset),
        .clock(dl_clock),
        .proc_dep_vld_vec(proc_dep_vld_vec_1),
        .in_chan_dep_vld_vec(in_chan_dep_vld_vec_1),
        .in_chan_dep_data_vec(in_chan_dep_data_vec_1),
        .token_in_vec(token_in_vec_1),
        .dl_detect_in(dl_detect_out),
        .origin(origin[1]),
        .token_clear(token_clear),
        .out_chan_dep_vld_vec(out_chan_dep_vld_vec_1),
        .out_chan_dep_data(out_chan_dep_data_1),
        .token_out_vec(token_out_vec_1),
        .dl_detect_out(dl_in_vec[1]));

    assign proc_1_data_FIFO_blk[0] = 1'b0;
    assign proc_1_data_PIPO_blk[0] = 1'b0;
    assign proc_1_start_FIFO_blk[0] = 1'b0;
    assign proc_1_TLF_FIFO_blk[0] = 1'b0 | (~r_gate_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_U.if_write) | (~z_gate_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_U.if_write) | (~r_gate_1_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_1_U.if_write) | (~z_gate_1_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_1_U.if_write) | (~r_gate_2_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_2_U.if_write) | (~z_gate_2_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_2_U.if_write) | (~r_gate_3_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_3_U.if_write) | (~z_gate_3_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_3_U.if_write) | (~r_gate_4_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_4_U.if_write) | (~z_gate_4_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_4_U.if_write) | (~r_gate_5_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_5_U.if_write) | (~z_gate_5_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_5_U.if_write) | (~r_gate_6_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_6_U.if_write) | (~z_gate_6_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_6_U.if_write) | (~r_gate_7_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_7_U.if_write) | (~z_gate_7_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_7_U.if_write) | (~r_gate_8_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_8_U.if_write) | (~z_gate_8_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_8_U.if_write) | (~r_gate_9_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_9_U.if_write) | (~z_gate_9_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_9_U.if_write) | (~r_gate_10_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_10_U.if_write) | (~z_gate_10_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_10_U.if_write) | (~r_gate_11_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_11_U.if_write) | (~z_gate_11_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_11_U.if_write) | (~r_gate_12_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_12_U.if_write) | (~z_gate_12_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_12_U.if_write) | (~r_gate_13_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_13_U.if_write) | (~z_gate_13_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_13_U.if_write) | (~r_gate_14_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~r_gate_14_U.if_write) | (~z_gate_14_U.if_empty_n & Block_entry_split_split_split_proc_U0.ap_idle & ~z_gate_14_U.if_write);
    assign proc_1_input_sync_blk[0] = 1'b0 | (ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & Block_entry_split_split_split_proc_U0.ap_idle & ~ap_sync_prepare_gates_U0_ap_ready);
    assign proc_1_output_sync_blk[0] = 1'b0;
    assign proc_dep_vld_vec_1[0] = dl_detect_out ? proc_dep_vld_vec_1_reg[0] : (proc_1_data_FIFO_blk[0] | proc_1_data_PIPO_blk[0] | proc_1_start_FIFO_blk[0] | proc_1_TLF_FIFO_blk[0] | proc_1_input_sync_blk[0] | proc_1_output_sync_blk[0]);
    assign proc_1_data_FIFO_blk[1] = 1'b0;
    assign proc_1_data_PIPO_blk[1] = 1'b0;
    assign proc_1_start_FIFO_blk[1] = 1'b0;
    assign proc_1_TLF_FIFO_blk[1] = 1'b0;
    assign proc_1_input_sync_blk[1] = 1'b0 | (ap_sync_Block_entry_split_split_split_proc_U0_ap_ready & Block_entry_split_split_split_proc_U0.ap_idle & ~ap_sync_Loop_LOOP_T_proc_U0_ap_ready);
    assign proc_1_output_sync_blk[1] = 1'b0;
    assign proc_dep_vld_vec_1[1] = dl_detect_out ? proc_dep_vld_vec_1_reg[1] : (proc_1_data_FIFO_blk[1] | proc_1_data_PIPO_blk[1] | proc_1_start_FIFO_blk[1] | proc_1_TLF_FIFO_blk[1] | proc_1_input_sync_blk[1] | proc_1_output_sync_blk[1]);
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            proc_dep_vld_vec_1_reg <= 'b0;
        end
        else begin
            proc_dep_vld_vec_1_reg <= proc_dep_vld_vec_1;
        end
    end
    assign in_chan_dep_vld_vec_1[0] = dep_chan_vld_0_1;
    assign in_chan_dep_data_vec_1[2 : 0] = dep_chan_data_0_1;
    assign token_in_vec_1[0] = token_0_1;
    assign in_chan_dep_vld_vec_1[1] = dep_chan_vld_2_1;
    assign in_chan_dep_data_vec_1[5 : 3] = dep_chan_data_2_1;
    assign token_in_vec_1[1] = token_2_1;
    assign dep_chan_vld_1_0 = out_chan_dep_vld_vec_1[0];
    assign dep_chan_data_1_0 = out_chan_dep_data_1;
    assign token_1_0 = token_out_vec_1[0];
    assign dep_chan_vld_1_2 = out_chan_dep_vld_vec_1[1];
    assign dep_chan_data_1_2 = out_chan_dep_data_1;
    assign token_1_2 = token_out_vec_1[1];

    // Process: Loop_LOOP_T_proc_U0
    ResGRU_hls_deadlock_detect_unit #(3, 2, 2, 2) ResGRU_hls_deadlock_detect_unit_2 (
        .reset(dl_reset),
        .clock(dl_clock),
        .proc_dep_vld_vec(proc_dep_vld_vec_2),
        .in_chan_dep_vld_vec(in_chan_dep_vld_vec_2),
        .in_chan_dep_data_vec(in_chan_dep_data_vec_2),
        .token_in_vec(token_in_vec_2),
        .dl_detect_in(dl_detect_out),
        .origin(origin[2]),
        .token_clear(token_clear),
        .out_chan_dep_vld_vec(out_chan_dep_vld_vec_2),
        .out_chan_dep_data(out_chan_dep_data_2),
        .token_out_vec(token_out_vec_2),
        .dl_detect_out(dl_in_vec[2]));

    assign proc_2_data_FIFO_blk[0] = 1'b0;
    assign proc_2_data_PIPO_blk[0] = 1'b0;
    assign proc_2_start_FIFO_blk[0] = 1'b0;
    assign proc_2_TLF_FIFO_blk[0] = 1'b0 | (~shl_i_i18_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i_1_cast_loc_channel_U.if_write) | (~sext_ln14_39_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_39_loc_channel_U.if_write) | (~sext_ln14_38_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_38_loc_channel_U.if_write) | (~sext_ln14_37_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_37_loc_channel_U.if_write) | (~sext_ln14_36_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_36_loc_channel_U.if_write) | (~sext_ln14_35_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_35_loc_channel_U.if_write) | (~shl_i_i18_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i_cast_loc_channel_U.if_write) | (~sext_ln14_34_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_34_loc_channel_U.if_write) | (~sext_ln14_33_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_33_loc_channel_U.if_write) | (~sext_ln14_32_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_32_loc_channel_U.if_write) | (~sext_ln14_31_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_31_loc_channel_U.if_write) | (~sext_ln14_30_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_30_loc_channel_U.if_write) | (~sext_ln385_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_2_loc_channel_U.if_write) | (~z_gate_14_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_14_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_4_cast_loc_channel_U.if_write) | (~z_gate_13_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_13_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_4_cast_loc_channel_U.if_write) | (~conv_i357_i_2_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_4_loc_channel_U.if_write) | (~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_3_cast_loc_channel_U.if_write) | (~z_gate_12_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_12_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_3_cast_loc_channel_U.if_write) | (~conv_i357_i_2_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_3_loc_channel_U.if_write) | (~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_2_cast_loc_channel_U.if_write) | (~z_gate_11_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_11_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_2_cast_loc_channel_U.if_write) | (~conv_i357_i_2_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_2_loc_channel_U.if_write) | (~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_1_cast_loc_channel_U.if_write) | (~z_gate_10_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_10_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_1_cast_loc_channel_U.if_write) | (~conv_i357_i_2_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_1_loc_channel_U.if_write) | (~shl_i_i18_i261_i_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_2_cast_loc_channel_U.if_write) | (~W_hn_2_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_0_load_loc_channel_U.if_write) | (~W_hn_2_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_1_load_loc_channel_U.if_write) | (~W_hn_2_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_2_load_loc_channel_U.if_write) | (~W_hn_2_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_3_load_loc_channel_U.if_write) | (~W_hn_2_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_0_4_load_loc_channel_U.if_write) | (~W_hn_2_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_0_load_loc_channel_U.if_write) | (~W_hn_2_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_1_load_loc_channel_U.if_write) | (~W_hn_2_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_2_load_loc_channel_U.if_write) | (~W_hn_2_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_3_load_loc_channel_U.if_write) | (~W_hn_2_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_1_4_load_loc_channel_U.if_write) | (~W_hn_2_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_0_load_loc_channel_U.if_write) | (~W_hn_2_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_1_load_loc_channel_U.if_write) | (~W_hn_2_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_2_load_loc_channel_U.if_write) | (~W_hn_2_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_3_load_loc_channel_U.if_write) | (~W_hn_2_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_2_4_load_loc_channel_U.if_write) | (~W_hn_2_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_0_load_loc_channel_U.if_write) | (~W_hn_2_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_1_load_loc_channel_U.if_write) | (~W_hn_2_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_2_load_loc_channel_U.if_write) | (~W_hn_2_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_3_load_loc_channel_U.if_write) | (~W_hn_2_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_3_4_load_loc_channel_U.if_write) | (~W_hn_2_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_0_load_loc_channel_U.if_write) | (~W_hn_2_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_1_load_loc_channel_U.if_write) | (~W_hn_2_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_2_load_loc_channel_U.if_write) | (~W_hn_2_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_3_load_loc_channel_U.if_write) | (~W_hn_2_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_2_4_4_load_loc_channel_U.if_write) | (~shl_i_i18_i409_i_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_2_cast_loc_channel_U.if_write) | (~conv_i357_i_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_2_loc_channel_U.if_write) | (~sext_ln90_74_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_74_loc_channel_U.if_write) | (~sext_ln90_73_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_73_loc_channel_U.if_write) | (~sext_ln90_72_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_72_loc_channel_U.if_write) | (~sext_ln90_71_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_71_loc_channel_U.if_write) | (~sext_ln90_70_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_70_loc_channel_U.if_write) | (~sext_ln90_69_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_69_loc_channel_U.if_write) | (~sext_ln90_68_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_68_loc_channel_U.if_write) | (~sext_ln90_67_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_67_loc_channel_U.if_write) | (~sext_ln90_66_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_66_loc_channel_U.if_write) | (~sext_ln90_65_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_65_loc_channel_U.if_write) | (~sext_ln90_64_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_64_loc_channel_U.if_write) | (~sext_ln90_63_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_63_loc_channel_U.if_write) | (~sext_ln90_62_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_62_loc_channel_U.if_write) | (~sext_ln90_61_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_61_loc_channel_U.if_write) | (~sext_ln90_60_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_60_loc_channel_U.if_write) | (~sext_ln90_59_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_59_loc_channel_U.if_write) | (~sext_ln90_58_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_58_loc_channel_U.if_write) | (~sext_ln90_57_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_57_loc_channel_U.if_write) | (~sext_ln90_56_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_56_loc_channel_U.if_write) | (~sext_ln90_55_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_55_loc_channel_U.if_write) | (~sext_ln90_54_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_54_loc_channel_U.if_write) | (~sext_ln90_53_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_53_loc_channel_U.if_write) | (~sext_ln90_52_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_52_loc_channel_U.if_write) | (~sext_ln90_51_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_51_loc_channel_U.if_write) | (~sext_ln90_50_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_50_loc_channel_U.if_write) | (~sext_ln385_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_1_loc_channel_U.if_write) | (~z_gate_9_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_9_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_4_cast_loc_channel_U.if_write) | (~z_gate_8_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_8_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_4_cast_loc_channel_U.if_write) | (~conv_i357_i_1_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_4_loc_channel_U.if_write) | (~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_3_cast_loc_channel_U.if_write) | (~z_gate_7_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_7_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_3_cast_loc_channel_U.if_write) | (~conv_i357_i_1_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_3_loc_channel_U.if_write) | (~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_2_cast_loc_channel_U.if_write) | (~z_gate_6_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_6_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_2_cast_loc_channel_U.if_write) | (~conv_i357_i_1_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_2_loc_channel_U.if_write) | (~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_1_cast_loc_channel_U.if_write) | (~z_gate_5_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_5_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_1_cast_loc_channel_U.if_write) | (~conv_i357_i_1_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_1_loc_channel_U.if_write) | (~shl_i_i18_i261_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_1_cast_loc_channel_U.if_write) | (~W_hn_1_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_0_load_loc_channel_U.if_write) | (~W_hn_1_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_1_load_loc_channel_U.if_write) | (~W_hn_1_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_2_load_loc_channel_U.if_write) | (~W_hn_1_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_3_load_loc_channel_U.if_write) | (~W_hn_1_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_0_4_load_loc_channel_U.if_write) | (~W_hn_1_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_0_load_loc_channel_U.if_write) | (~W_hn_1_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_1_load_loc_channel_U.if_write) | (~W_hn_1_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_2_load_loc_channel_U.if_write) | (~W_hn_1_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_3_load_loc_channel_U.if_write) | (~W_hn_1_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_1_4_load_loc_channel_U.if_write) | (~W_hn_1_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_0_load_loc_channel_U.if_write) | (~W_hn_1_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_1_load_loc_channel_U.if_write) | (~W_hn_1_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_2_load_loc_channel_U.if_write) | (~W_hn_1_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_3_load_loc_channel_U.if_write) | (~W_hn_1_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_2_4_load_loc_channel_U.if_write) | (~W_hn_1_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_0_load_loc_channel_U.if_write) | (~W_hn_1_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_1_load_loc_channel_U.if_write) | (~W_hn_1_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_2_load_loc_channel_U.if_write) | (~W_hn_1_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_3_load_loc_channel_U.if_write) | (~W_hn_1_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_3_4_load_loc_channel_U.if_write) | (~W_hn_1_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_0_load_loc_channel_U.if_write) | (~W_hn_1_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_1_load_loc_channel_U.if_write) | (~W_hn_1_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_2_load_loc_channel_U.if_write) | (~W_hn_1_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_3_load_loc_channel_U.if_write) | (~W_hn_1_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_1_4_4_load_loc_channel_U.if_write) | (~shl_i_i18_i409_i_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_1_cast_loc_channel_U.if_write) | (~conv_i357_i_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_1_loc_channel_U.if_write) | (~sext_ln90_49_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_49_loc_channel_U.if_write) | (~sext_ln90_48_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_48_loc_channel_U.if_write) | (~sext_ln90_47_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_47_loc_channel_U.if_write) | (~sext_ln90_46_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_46_loc_channel_U.if_write) | (~sext_ln90_45_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_45_loc_channel_U.if_write) | (~sext_ln90_44_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_44_loc_channel_U.if_write) | (~sext_ln90_43_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_43_loc_channel_U.if_write) | (~sext_ln90_42_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_42_loc_channel_U.if_write) | (~sext_ln90_41_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_41_loc_channel_U.if_write) | (~sext_ln90_40_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_40_loc_channel_U.if_write) | (~sext_ln90_39_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_39_loc_channel_U.if_write) | (~sext_ln90_38_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_38_loc_channel_U.if_write) | (~sext_ln90_37_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_37_loc_channel_U.if_write) | (~sext_ln90_36_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_36_loc_channel_U.if_write) | (~sext_ln90_35_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_35_loc_channel_U.if_write) | (~sext_ln90_34_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_34_loc_channel_U.if_write) | (~sext_ln90_33_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_33_loc_channel_U.if_write) | (~sext_ln90_32_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_32_loc_channel_U.if_write) | (~sext_ln90_31_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_31_loc_channel_U.if_write) | (~sext_ln90_30_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_30_loc_channel_U.if_write) | (~sext_ln90_29_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_29_loc_channel_U.if_write) | (~sext_ln90_28_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_28_loc_channel_U.if_write) | (~sext_ln90_27_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_27_loc_channel_U.if_write) | (~sext_ln90_26_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_26_loc_channel_U.if_write) | (~sext_ln90_25_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_25_loc_channel_U.if_write) | (~sext_ln385_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln385_loc_channel_U.if_write) | (~z_gate_4_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_4_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i261_i_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_4_cast_loc_channel_U.if_write) | (~z_gate_3_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_3_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_4_cast_loc_channel_U.if_write) | (~conv_i357_i_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_4_loc_channel_U.if_write) | (~shl_i_i18_i261_i_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_3_cast_loc_channel_U.if_write) | (~z_gate_2_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_2_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_3_cast_loc_channel_U.if_write) | (~conv_i357_i_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_3_loc_channel_U.if_write) | (~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_21855_cast_loc_channel_U.if_write) | (~z_gate_1_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_1_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_21770_cast_loc_channel_U.if_write) | (~conv_i357_i_21781_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_21781_loc_channel_U.if_write) | (~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_11612_cast_loc_channel_U.if_write) | (~z_gate_load_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~z_gate_load_cast_loc_channel_U.if_write) | (~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_11527_cast_loc_channel_U.if_write) | (~conv_i357_i_11538_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_11538_loc_channel_U.if_write) | (~shl_i_i18_i261_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i261_i_cast_loc_channel_U.if_write) | (~W_hn_0_0_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_0_load_loc_channel_U.if_write) | (~W_hn_0_0_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_1_load_loc_channel_U.if_write) | (~W_hn_0_0_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_2_load_loc_channel_U.if_write) | (~W_hn_0_0_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_3_load_loc_channel_U.if_write) | (~W_hn_0_0_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_0_4_load_loc_channel_U.if_write) | (~W_hn_0_1_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_0_load_loc_channel_U.if_write) | (~W_hn_0_1_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_1_load_loc_channel_U.if_write) | (~W_hn_0_1_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_2_load_loc_channel_U.if_write) | (~W_hn_0_1_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_3_load_loc_channel_U.if_write) | (~W_hn_0_1_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_1_4_load_loc_channel_U.if_write) | (~W_hn_0_2_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_0_load_loc_channel_U.if_write) | (~W_hn_0_2_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_1_load_loc_channel_U.if_write) | (~W_hn_0_2_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_2_load_loc_channel_U.if_write) | (~W_hn_0_2_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_3_load_loc_channel_U.if_write) | (~W_hn_0_2_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_2_4_load_loc_channel_U.if_write) | (~W_hn_0_3_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_0_load_loc_channel_U.if_write) | (~W_hn_0_3_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_1_load_loc_channel_U.if_write) | (~W_hn_0_3_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_2_load_loc_channel_U.if_write) | (~W_hn_0_3_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_3_load_loc_channel_U.if_write) | (~W_hn_0_3_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_3_4_load_loc_channel_U.if_write) | (~W_hn_0_4_0_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_0_load_loc_channel_U.if_write) | (~W_hn_0_4_1_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_1_load_loc_channel_U.if_write) | (~W_hn_0_4_2_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_2_load_loc_channel_U.if_write) | (~W_hn_0_4_3_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_3_load_loc_channel_U.if_write) | (~W_hn_0_4_4_load_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~W_hn_0_4_4_load_loc_channel_U.if_write) | (~shl_i_i18_i409_i_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~shl_i_i18_i409_i_cast_loc_channel_U.if_write) | (~conv_i357_i_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv_i357_i_loc_channel_U.if_write) | (~sext_ln90_24_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_24_loc_channel_U.if_write) | (~sext_ln90_23_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_23_loc_channel_U.if_write) | (~sext_ln90_22_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_22_loc_channel_U.if_write) | (~sext_ln90_21_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_21_loc_channel_U.if_write) | (~sext_ln90_20_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_20_loc_channel_U.if_write) | (~sext_ln90_19_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_19_loc_channel_U.if_write) | (~sext_ln90_18_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_18_loc_channel_U.if_write) | (~sext_ln90_17_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_17_loc_channel_U.if_write) | (~sext_ln90_16_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_16_loc_channel_U.if_write) | (~sext_ln90_15_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_15_loc_channel_U.if_write) | (~sext_ln90_14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_14_loc_channel_U.if_write) | (~sext_ln90_13_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_13_loc_channel_U.if_write) | (~sext_ln90_12_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_12_loc_channel_U.if_write) | (~sext_ln90_11_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_11_loc_channel_U.if_write) | (~sext_ln90_10_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_10_loc_channel_U.if_write) | (~sext_ln90_9_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_9_loc_channel_U.if_write) | (~sext_ln90_8_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_8_loc_channel_U.if_write) | (~sext_ln90_7_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_7_loc_channel_U.if_write) | (~sext_ln90_6_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_6_loc_channel_U.if_write) | (~sext_ln90_5_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_5_loc_channel_U.if_write) | (~sext_ln90_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_4_loc_channel_U.if_write) | (~sext_ln90_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_3_loc_channel_U.if_write) | (~sext_ln90_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_2_loc_channel_U.if_write) | (~sext_ln90_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_1_loc_channel_U.if_write) | (~sext_ln90_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln90_loc_channel_U.if_write) | (~conv7_i_i844_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~conv7_i_i844_loc_channel_U.if_write) | (~trunc_ln46_4_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_4_cast_loc_channel_U.if_write) | (~trunc_ln46_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_4_loc_channel_U.if_write) | (~sext_ln14_29_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_29_loc_channel_U.if_write) | (~sext_ln14_28_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_28_loc_channel_U.if_write) | (~sext_ln14_27_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_27_loc_channel_U.if_write) | (~sext_ln14_26_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_26_loc_channel_U.if_write) | (~sext_ln14_25_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_25_loc_channel_U.if_write) | (~trunc_ln46_3_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_3_cast_loc_channel_U.if_write) | (~trunc_ln46_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_3_loc_channel_U.if_write) | (~sext_ln14_24_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_24_loc_channel_U.if_write) | (~sext_ln14_23_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_23_loc_channel_U.if_write) | (~sext_ln14_22_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_22_loc_channel_U.if_write) | (~sext_ln14_21_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_21_loc_channel_U.if_write) | (~sext_ln14_20_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_20_loc_channel_U.if_write) | (~sext_ln14_19_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_19_loc_channel_U.if_write) | (~trunc_ln46_2_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_2_cast_loc_channel_U.if_write) | (~trunc_ln46_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_2_loc_channel_U.if_write) | (~sext_ln14_18_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_18_loc_channel_U.if_write) | (~sext_ln14_17_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_17_loc_channel_U.if_write) | (~sext_ln14_16_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_16_loc_channel_U.if_write) | (~sext_ln14_15_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_15_loc_channel_U.if_write) | (~sext_ln14_14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_14_loc_channel_U.if_write) | (~sext_ln14_13_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_13_loc_channel_U.if_write) | (~trunc_ln46_1_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_1_cast_loc_channel_U.if_write) | (~trunc_ln46_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_1_loc_channel_U.if_write) | (~sext_ln14_12_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_12_loc_channel_U.if_write) | (~sext_ln14_11_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_11_loc_channel_U.if_write) | (~sext_ln14_10_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_10_loc_channel_U.if_write) | (~sext_ln14_9_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_9_loc_channel_U.if_write) | (~sext_ln14_8_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_8_loc_channel_U.if_write) | (~sext_ln14_7_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_7_loc_channel_U.if_write) | (~trunc_ln46_cast_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_cast_loc_channel_U.if_write) | (~trunc_ln46_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~trunc_ln46_loc_channel_U.if_write) | (~sext_ln14_6_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_6_loc_channel_U.if_write) | (~sext_ln14_5_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_5_loc_channel_U.if_write) | (~sext_ln14_4_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_4_loc_channel_U.if_write) | (~sext_ln14_3_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_3_loc_channel_U.if_write) | (~sext_ln14_2_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_2_loc_channel_U.if_write) | (~sext_ln14_1_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_1_loc_channel_U.if_write) | (~sext_ln14_loc_channel_U.if_empty_n & Loop_LOOP_T_proc_U0.ap_idle & ~sext_ln14_loc_channel_U.if_write);
    assign proc_2_input_sync_blk[0] = 1'b0 | (ap_sync_Loop_LOOP_T_proc_U0_ap_ready & Loop_LOOP_T_proc_U0.ap_idle & ~ap_sync_Block_entry_split_split_split_proc_U0_ap_ready);
    assign proc_2_output_sync_blk[0] = 1'b0;
    assign proc_dep_vld_vec_2[0] = dl_detect_out ? proc_dep_vld_vec_2_reg[0] : (proc_2_data_FIFO_blk[0] | proc_2_data_PIPO_blk[0] | proc_2_start_FIFO_blk[0] | proc_2_TLF_FIFO_blk[0] | proc_2_input_sync_blk[0] | proc_2_output_sync_blk[0]);
    assign proc_2_data_FIFO_blk[1] = 1'b0;
    assign proc_2_data_PIPO_blk[1] = 1'b0;
    assign proc_2_start_FIFO_blk[1] = 1'b0;
    assign proc_2_TLF_FIFO_blk[1] = 1'b0;
    assign proc_2_input_sync_blk[1] = 1'b0 | (ap_sync_Loop_LOOP_T_proc_U0_ap_ready & Loop_LOOP_T_proc_U0.ap_idle & ~ap_sync_prepare_gates_U0_ap_ready);
    assign proc_2_output_sync_blk[1] = 1'b0;
    assign proc_dep_vld_vec_2[1] = dl_detect_out ? proc_dep_vld_vec_2_reg[1] : (proc_2_data_FIFO_blk[1] | proc_2_data_PIPO_blk[1] | proc_2_start_FIFO_blk[1] | proc_2_TLF_FIFO_blk[1] | proc_2_input_sync_blk[1] | proc_2_output_sync_blk[1]);
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            proc_dep_vld_vec_2_reg <= 'b0;
        end
        else begin
            proc_dep_vld_vec_2_reg <= proc_dep_vld_vec_2;
        end
    end
    assign in_chan_dep_vld_vec_2[0] = dep_chan_vld_0_2;
    assign in_chan_dep_data_vec_2[2 : 0] = dep_chan_data_0_2;
    assign token_in_vec_2[0] = token_0_2;
    assign in_chan_dep_vld_vec_2[1] = dep_chan_vld_1_2;
    assign in_chan_dep_data_vec_2[5 : 3] = dep_chan_data_1_2;
    assign token_in_vec_2[1] = token_1_2;
    assign dep_chan_vld_2_1 = out_chan_dep_vld_vec_2[0];
    assign dep_chan_data_2_1 = out_chan_dep_data_2;
    assign token_2_1 = token_out_vec_2[0];
    assign dep_chan_vld_2_0 = out_chan_dep_vld_vec_2[1];
    assign dep_chan_data_2_0 = out_chan_dep_data_2;
    assign token_2_0 = token_out_vec_2[1];


`include "ResGRU_hls_deadlock_report_unit.vh"
