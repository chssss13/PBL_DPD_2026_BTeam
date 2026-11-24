`timescale 1ns/1ps
module probe;
reg clk=0,rst=1,start=0,seg=0;reg [13:0] weight=0;
always #5 clk=~clk;
reg [14:0] iq[0:15359];reg [13:0] gate[0:2];
integer finished_push=0;integer cycle=0,accepted=0,finished=0,writes=0,reads=0;
initial begin $readmemh("iq.hex",iq);$readmemh("gate.hex",gate);repeat(4) @(negedge clk);weight=101;seg=1;rst=0;start=1;end
reg [14:0] b_ir_0_q0=0;
reg [14:0] mem_b_ir_0[0:4]; initial begin mem_b_ir_0[0]=15'd758;mem_b_ir_0[1]=15'd2262;mem_b_ir_0[2]=15'd607;mem_b_ir_0[3]=15'd2489;mem_b_ir_0[4]=15'd685;end
reg [14:0] b_ir_0_q1=0;
reg [14:0] b_ir_1_q0=0;
reg [14:0] mem_b_ir_1[0:4]; initial begin mem_b_ir_1[0]=15'd225;mem_b_ir_1[1]=15'd377;mem_b_ir_1[2]=15'd149;mem_b_ir_1[3]=15'd367;mem_b_ir_1[4]=15'd32754;end
reg [14:0] b_ir_1_q1=0;
reg [14:0] b_ir_2_q0=0;
reg [14:0] mem_b_ir_2[0:4]; initial begin mem_b_ir_2[0]=15'd806;mem_b_ir_2[1]=15'd2427;mem_b_ir_2[2]=15'd3747;mem_b_ir_2[3]=15'd31799;mem_b_ir_2[4]=15'd3763;end
reg [14:0] b_ir_2_q1=0;
reg [14:0] b_hr_0_q0=0;
reg [14:0] mem_b_hr_0[0:4]; initial begin mem_b_hr_0[0]=15'd758;mem_b_hr_0[1]=15'd2262;mem_b_hr_0[2]=15'd607;mem_b_hr_0[3]=15'd2489;mem_b_hr_0[4]=15'd685;end
reg [14:0] b_hr_0_q1=0;
reg [14:0] b_hr_1_q0=0;
reg [14:0] mem_b_hr_1[0:4]; initial begin mem_b_hr_1[0]=15'd225;mem_b_hr_1[1]=15'd377;mem_b_hr_1[2]=15'd149;mem_b_hr_1[3]=15'd367;mem_b_hr_1[4]=15'd32754;end
reg [14:0] b_hr_1_q1=0;
reg [14:0] b_hr_2_q0=0;
reg [14:0] mem_b_hr_2[0:4]; initial begin mem_b_hr_2[0]=15'd806;mem_b_hr_2[1]=15'd2427;mem_b_hr_2[2]=15'd3747;mem_b_hr_2[3]=15'd31799;mem_b_hr_2[4]=15'd3763;end
reg [14:0] b_hr_2_q1=0;
reg [14:0] b_iz_0_q0=0;
reg [14:0] mem_b_iz_0[0:4]; initial begin mem_b_iz_0[0]=15'd30876;mem_b_iz_0[1]=15'd32307;mem_b_iz_0[2]=15'd30892;mem_b_iz_0[3]=15'd30303;mem_b_iz_0[4]=15'd31382;end
reg [14:0] b_iz_0_q1=0;
reg [14:0] b_iz_1_q0=0;
reg [14:0] mem_b_iz_1[0:4]; initial begin mem_b_iz_1[0]=15'd31190;mem_b_iz_1[1]=15'd31403;mem_b_iz_1[2]=15'd30232;mem_b_iz_1[3]=15'd30214;mem_b_iz_1[4]=15'd31251;end
reg [14:0] b_iz_1_q1=0;
reg [14:0] b_iz_2_q0=0;
reg [14:0] mem_b_iz_2[0:4]; initial begin mem_b_iz_2[0]=15'd32179;mem_b_iz_2[1]=15'd32353;mem_b_iz_2[2]=15'd31373;mem_b_iz_2[3]=15'd31623;mem_b_iz_2[4]=15'd31988;end
reg [14:0] b_iz_2_q1=0;
reg [14:0] b_hz_0_q0=0;
reg [14:0] mem_b_hz_0[0:4]; initial begin mem_b_hz_0[0]=15'd30876;mem_b_hz_0[1]=15'd32307;mem_b_hz_0[2]=15'd30892;mem_b_hz_0[3]=15'd30303;mem_b_hz_0[4]=15'd31382;end
reg [14:0] b_hz_0_q1=0;
reg [14:0] b_hz_1_q0=0;
reg [14:0] mem_b_hz_1[0:4]; initial begin mem_b_hz_1[0]=15'd31190;mem_b_hz_1[1]=15'd31403;mem_b_hz_1[2]=15'd30232;mem_b_hz_1[3]=15'd30214;mem_b_hz_1[4]=15'd31251;end
reg [14:0] b_hz_1_q1=0;
reg [14:0] b_hz_2_q0=0;
reg [14:0] mem_b_hz_2[0:4]; initial begin mem_b_hz_2[0]=15'd32179;mem_b_hz_2[1]=15'd32353;mem_b_hz_2[2]=15'd31373;mem_b_hz_2[3]=15'd31623;mem_b_hz_2[4]=15'd31988;end
reg [14:0] b_hz_2_q1=0;
reg [14:0] b_in_0_q0=0;
reg [14:0] mem_b_in_0[0:4]; initial begin mem_b_in_0[0]=15'd648;mem_b_in_0[1]=15'd33;mem_b_in_0[2]=15'd598;mem_b_in_0[3]=15'd31974;mem_b_in_0[4]=15'd242;end
reg [14:0] b_in_0_q1=0;
reg [14:0] b_in_1_q0=0;
reg [14:0] mem_b_in_1[0:4]; initial begin mem_b_in_1[0]=15'd32726;mem_b_in_1[1]=15'd283;mem_b_in_1[2]=15'd32530;mem_b_in_1[3]=15'd367;mem_b_in_1[4]=15'd32687;end
reg [14:0] b_in_1_q1=0;
reg [14:0] b_in_2_q0=0;
reg [14:0] mem_b_in_2[0:4]; initial begin mem_b_in_2[0]=15'd32416;mem_b_in_2[1]=15'd32736;mem_b_in_2[2]=15'd32753;mem_b_in_2[3]=15'd115;mem_b_in_2[4]=15'd32416;end
reg [14:0] b_in_2_q1=0;
reg [14:0] b_hn_0_q0=0;
reg [14:0] mem_b_hn_0[0:4]; initial begin mem_b_hn_0[0]=15'd340;mem_b_hn_0[1]=15'd27;mem_b_hn_0[2]=15'd745;mem_b_hn_0[3]=15'd32036;mem_b_hn_0[4]=15'd280;end
reg [14:0] b_hn_0_q1=0;
reg [14:0] b_hn_1_q0=0;
reg [14:0] mem_b_hn_1[0:4]; initial begin mem_b_hn_1[0]=15'd128;mem_b_hn_1[1]=15'd122;mem_b_hn_1[2]=15'd32389;mem_b_hn_1[3]=15'd444;mem_b_hn_1[4]=15'd32476;end
reg [14:0] b_hn_1_q1=0;
reg [14:0] b_hn_2_q0=0;
reg [14:0] mem_b_hn_2[0:4]; initial begin mem_b_hn_2[0]=15'd32273;mem_b_hn_2[1]=15'd32693;mem_b_hn_2[2]=15'd32690;mem_b_hn_2[3]=15'd126;mem_b_hn_2[4]=15'd32343;end
reg [14:0] b_hn_2_q1=0;
reg [14:0] IQ_seq_q0=0;reg [13:0] gating_params_q0=0;
reg [14:0] IQ_seq_q1=0;reg [13:0] gating_params_q1=0;
ResGRU dut(.IQ_seq_q0(IQ_seq_q0),
.IQ_seq_q1(IQ_seq_q1),
.OUT_seq_q0(15'd0),
.OUT_seq_q1(15'd0),
.W_inj_0_0(14'd525),
.W_inj_0_1(14'd15929),
.W_inj_0_2(14'd17),
.W_inj_0_3(14'd15836),
.W_inj_0_4(14'd204),
.W_inj_0_5(14'd52),
.W_inj_1_0(14'd15369),
.W_inj_1_1(14'd16227),
.W_inj_1_2(14'd16383),
.W_inj_1_3(14'd15868),
.W_inj_1_4(14'd64),
.W_inj_1_5(14'd16379),
.W_inj_2_0(14'd15518),
.W_inj_2_1(14'd882),
.W_inj_2_2(14'd70),
.W_inj_2_3(14'd241),
.W_inj_2_4(14'd198),
.W_inj_2_5(14'd81),
.W_inj_3_0(14'd15751),
.W_inj_3_1(14'd15396),
.W_inj_3_2(14'd16360),
.W_inj_3_3(14'd39),
.W_inj_3_4(14'd16326),
.W_inj_3_5(14'd1),
.W_inj_4_0(14'd146),
.W_inj_4_1(14'd15908),
.W_inj_4_2(14'd91),
.W_inj_4_3(14'd1617),
.W_inj_4_4(14'd16340),
.W_inj_4_5(14'd17),
.b_inj_0(15'd32711),
.b_inj_1(15'd32709),
.b_inj_2(15'd32748),
.b_inj_3(15'd32205),
.b_inj_4(15'd32295),
.prelu_param(14'd1039),
.gating_params_q0(gating_params_q0),
.gating_params_q1(gating_params_q1),
.W_in_0_0_0(14'd154),
.W_in_0_0_1(14'd127),
.W_in_0_0_2(14'd16181),
.W_in_0_0_3(14'd15916),
.W_in_0_0_4(14'd115),
.W_in_0_1_0(14'd299),
.W_in_0_1_1(14'd41),
.W_in_0_1_2(14'd255),
.W_in_0_1_3(14'd275),
.W_in_0_1_4(14'd152),
.W_in_0_2_0(14'd37),
.W_in_0_2_1(14'd428),
.W_in_0_2_2(14'd15924),
.W_in_0_2_3(14'd16373),
.W_in_0_2_4(14'd72),
.W_in_0_3_0(14'd289),
.W_in_0_3_1(14'd365),
.W_in_0_3_2(14'd15970),
.W_in_0_3_3(14'd16165),
.W_in_0_3_4(14'd354),
.W_in_0_4_0(14'd58),
.W_in_0_4_1(14'd16290),
.W_in_0_4_2(14'd228),
.W_in_0_4_3(14'd16198),
.W_in_0_4_4(14'd42),
.W_in_1_0_0(14'd16209),
.W_in_1_0_1(14'd15833),
.W_in_1_0_2(14'd16352),
.W_in_1_0_3(14'd16209),
.W_in_1_0_4(14'd16224),
.W_in_1_1_0(14'd16132),
.W_in_1_1_1(14'd338),
.W_in_1_1_2(14'd260),
.W_in_1_1_3(14'd16174),
.W_in_1_1_4(14'd26),
.W_in_1_2_0(14'd16243),
.W_in_1_2_1(14'd22),
.W_in_1_2_2(14'd16181),
.W_in_1_2_3(14'd369),
.W_in_1_2_4(14'd16251),
.W_in_1_3_0(14'd392),
.W_in_1_3_1(14'd123),
.W_in_1_3_2(14'd128),
.W_in_1_3_3(14'd158),
.W_in_1_3_4(14'd28),
.W_in_1_4_0(14'd5),
.W_in_1_4_1(14'd80),
.W_in_1_4_2(14'd16343),
.W_in_1_4_3(14'd22),
.W_in_1_4_4(14'd16020),
.W_in_2_0_0(14'd34),
.W_in_2_0_1(14'd49),
.W_in_2_0_2(14'd92),
.W_in_2_0_3(14'd15946),
.W_in_2_0_4(14'd16369),
.W_in_2_1_0(14'd16014),
.W_in_2_1_1(14'd337),
.W_in_2_1_2(14'd16291),
.W_in_2_1_3(14'd16179),
.W_in_2_1_4(14'd158),
.W_in_2_2_0(14'd71),
.W_in_2_2_1(14'd16360),
.W_in_2_2_2(14'd16130),
.W_in_2_2_3(14'd235),
.W_in_2_2_4(14'd16349),
.W_in_2_3_0(14'd155),
.W_in_2_3_1(14'd16118),
.W_in_2_3_2(14'd16143),
.W_in_2_3_3(14'd146),
.W_in_2_3_4(14'd123),
.W_in_2_4_0(14'd63),
.W_in_2_4_1(14'd16156),
.W_in_2_4_2(14'd15915),
.W_in_2_4_3(14'd16097),
.W_in_2_4_4(14'd15999),
.W_hn_0_0_0(14'd15940),
.W_hn_0_0_1(14'd110),
.W_hn_0_0_2(14'd16278),
.W_hn_0_0_3(14'd334),
.W_hn_0_0_4(14'd144),
.W_hn_0_1_0(14'd478),
.W_hn_0_1_1(14'd15823),
.W_hn_0_1_2(14'd64),
.W_hn_0_1_3(14'd362),
.W_hn_0_1_4(14'd19),
.W_hn_0_2_0(14'd16007),
.W_hn_0_2_1(14'd16184),
.W_hn_0_2_2(14'd110),
.W_hn_0_2_3(14'd16335),
.W_hn_0_2_4(14'd188),
.W_hn_0_3_0(14'd16168),
.W_hn_0_3_1(14'd16268),
.W_hn_0_3_2(14'd16136),
.W_hn_0_3_3(14'd15932),
.W_hn_0_3_4(14'd16218),
.W_hn_0_4_0(14'd16302),
.W_hn_0_4_1(14'd16059),
.W_hn_0_4_2(14'd16041),
.W_hn_0_4_3(14'd16140),
.W_hn_0_4_4(14'd16300),
.W_hn_1_0_0(14'd16354),
.W_hn_1_0_1(14'd16364),
.W_hn_1_0_2(14'd15788),
.W_hn_1_0_3(14'd16333),
.W_hn_1_0_4(14'd15992),
.W_hn_1_1_0(14'd246),
.W_hn_1_1_1(14'd15985),
.W_hn_1_1_2(14'd208),
.W_hn_1_1_3(14'd164),
.W_hn_1_1_4(14'd16104),
.W_hn_1_2_0(14'd309),
.W_hn_1_2_1(14'd16313),
.W_hn_1_2_2(14'd16021),
.W_hn_1_2_3(14'd217),
.W_hn_1_2_4(14'd16117),
.W_hn_1_3_0(14'd113),
.W_hn_1_3_1(14'd410),
.W_hn_1_3_2(14'd16375),
.W_hn_1_3_3(14'd16099),
.W_hn_1_3_4(14'd65),
.W_hn_1_4_0(14'd16348),
.W_hn_1_4_1(14'd308),
.W_hn_1_4_2(14'd558),
.W_hn_1_4_3(14'd270),
.W_hn_1_4_4(14'd16183),
.W_hn_2_0_0(14'd16264),
.W_hn_2_0_1(14'd428),
.W_hn_2_0_2(14'd1039),
.W_hn_2_0_3(14'd15946),
.W_hn_2_0_4(14'd15800),
.W_hn_2_1_0(14'd15937),
.W_hn_2_1_1(14'd331),
.W_hn_2_1_2(14'd1),
.W_hn_2_1_3(14'd125),
.W_hn_2_1_4(14'd726),
.W_hn_2_2_0(14'd15967),
.W_hn_2_2_1(14'd596),
.W_hn_2_2_2(14'd663),
.W_hn_2_2_3(14'd16237),
.W_hn_2_2_4(14'd526),
.W_hn_2_3_0(14'd148),
.W_hn_2_3_1(14'd208),
.W_hn_2_3_2(14'd16304),
.W_hn_2_3_3(14'd16235),
.W_hn_2_3_4(14'd16340),
.W_hn_2_4_0(14'd15512),
.W_hn_2_4_1(14'd16312),
.W_hn_2_4_2(14'd15426),
.W_hn_2_4_3(14'd15982),
.W_hn_2_4_4(14'd16093),
.b_ir_0_q0(b_ir_0_q0),
.b_ir_0_q1(b_ir_0_q1),
.b_ir_1_q0(b_ir_1_q0),
.b_ir_1_q1(b_ir_1_q1),
.b_ir_2_q0(b_ir_2_q0),
.b_ir_2_q1(b_ir_2_q1),
.b_hr_0_q0(b_hr_0_q0),
.b_hr_0_q1(b_hr_0_q1),
.b_hr_1_q0(b_hr_1_q0),
.b_hr_1_q1(b_hr_1_q1),
.b_hr_2_q0(b_hr_2_q0),
.b_hr_2_q1(b_hr_2_q1),
.b_iz_0_q0(b_iz_0_q0),
.b_iz_0_q1(b_iz_0_q1),
.b_iz_1_q0(b_iz_1_q0),
.b_iz_1_q1(b_iz_1_q1),
.b_iz_2_q0(b_iz_2_q0),
.b_iz_2_q1(b_iz_2_q1),
.b_hz_0_q0(b_hz_0_q0),
.b_hz_0_q1(b_hz_0_q1),
.b_hz_1_q0(b_hz_1_q0),
.b_hz_1_q1(b_hz_1_q1),
.b_hz_2_q0(b_hz_2_q0),
.b_hz_2_q1(b_hz_2_q1),
.b_in_0_q0(b_in_0_q0),
.b_in_0_q1(b_in_0_q1),
.b_in_1_q0(b_in_1_q0),
.b_in_1_q1(b_in_1_q1),
.b_in_2_q0(b_in_2_q0),
.b_in_2_q1(b_in_2_q1),
.b_hn_0_q0(b_hn_0_q0),
.b_hn_0_q1(b_hn_0_q1),
.b_hn_1_q0(b_hn_1_q0),
.b_hn_1_q1(b_hn_1_q1),
.b_hn_2_q0(b_hn_2_q0),
.b_hn_2_q1(b_hn_2_q1),
.W_out_0_0(14'd703),
.W_out_0_1(14'd15918),
.W_out_0_2(14'd4),
.W_out_0_3(14'd595),
.W_out_0_4(14'd376),
.W_out_1_0(14'd567),
.W_out_1_1(14'd111),
.W_out_1_2(14'd15971),
.W_out_1_3(14'd15399),
.W_out_1_4(14'd527),
.b_out_0(15'd143),
.b_out_1(15'd32710),
.segment_start(seg),
.ap_clk(clk),
.ap_rst(rst),
.ap_start(start),
.W_ir_0_q0(14'd0),
.W_ir_1_q0(14'd0),
.W_ir_2_q0(14'd0),
.W_iz_0_q0(14'd0),
.W_iz_1_q0(14'd0),
.W_iz_2_q0(14'd0),
.W_hr_0_q0(14'd0),
.W_hr_1_q0(14'd0),
.W_hr_2_q0(14'd0),
.W_hz_0_q0(14'd0),
.W_hz_1_q0(14'd0),
.W_hz_2_q0(14'd0));
always @(posedge clk) if(!rst) begin
cycle=cycle+1;
if(dut.b_ir_0_ce0) b_ir_0_q0<=mem_b_ir_0[dut.b_ir_0_address0];
if(dut.b_ir_0_ce1) b_ir_0_q1<=mem_b_ir_0[dut.b_ir_0_address1];
if(dut.b_ir_1_ce0) b_ir_1_q0<=mem_b_ir_1[dut.b_ir_1_address0];
if(dut.b_ir_1_ce1) b_ir_1_q1<=mem_b_ir_1[dut.b_ir_1_address1];
if(dut.b_ir_2_ce0) b_ir_2_q0<=mem_b_ir_2[dut.b_ir_2_address0];
if(dut.b_ir_2_ce1) b_ir_2_q1<=mem_b_ir_2[dut.b_ir_2_address1];
if(dut.b_hr_0_ce0) b_hr_0_q0<=mem_b_hr_0[dut.b_hr_0_address0];
if(dut.b_hr_0_ce1) b_hr_0_q1<=mem_b_hr_0[dut.b_hr_0_address1];
if(dut.b_hr_1_ce0) b_hr_1_q0<=mem_b_hr_1[dut.b_hr_1_address0];
if(dut.b_hr_1_ce1) b_hr_1_q1<=mem_b_hr_1[dut.b_hr_1_address1];
if(dut.b_hr_2_ce0) b_hr_2_q0<=mem_b_hr_2[dut.b_hr_2_address0];
if(dut.b_hr_2_ce1) b_hr_2_q1<=mem_b_hr_2[dut.b_hr_2_address1];
if(dut.b_iz_0_ce0) b_iz_0_q0<=mem_b_iz_0[dut.b_iz_0_address0];
if(dut.b_iz_0_ce1) b_iz_0_q1<=mem_b_iz_0[dut.b_iz_0_address1];
if(dut.b_iz_1_ce0) b_iz_1_q0<=mem_b_iz_1[dut.b_iz_1_address0];
if(dut.b_iz_1_ce1) b_iz_1_q1<=mem_b_iz_1[dut.b_iz_1_address1];
if(dut.b_iz_2_ce0) b_iz_2_q0<=mem_b_iz_2[dut.b_iz_2_address0];
if(dut.b_iz_2_ce1) b_iz_2_q1<=mem_b_iz_2[dut.b_iz_2_address1];
if(dut.b_hz_0_ce0) b_hz_0_q0<=mem_b_hz_0[dut.b_hz_0_address0];
if(dut.b_hz_0_ce1) b_hz_0_q1<=mem_b_hz_0[dut.b_hz_0_address1];
if(dut.b_hz_1_ce0) b_hz_1_q0<=mem_b_hz_1[dut.b_hz_1_address0];
if(dut.b_hz_1_ce1) b_hz_1_q1<=mem_b_hz_1[dut.b_hz_1_address1];
if(dut.b_hz_2_ce0) b_hz_2_q0<=mem_b_hz_2[dut.b_hz_2_address0];
if(dut.b_hz_2_ce1) b_hz_2_q1<=mem_b_hz_2[dut.b_hz_2_address1];
if(dut.b_in_0_ce0) b_in_0_q0<=mem_b_in_0[dut.b_in_0_address0];
if(dut.b_in_0_ce1) b_in_0_q1<=mem_b_in_0[dut.b_in_0_address1];
if(dut.b_in_1_ce0) b_in_1_q0<=mem_b_in_1[dut.b_in_1_address0];
if(dut.b_in_1_ce1) b_in_1_q1<=mem_b_in_1[dut.b_in_1_address1];
if(dut.b_in_2_ce0) b_in_2_q0<=mem_b_in_2[dut.b_in_2_address0];
if(dut.b_in_2_ce1) b_in_2_q1<=mem_b_in_2[dut.b_in_2_address1];
if(dut.b_hn_0_ce0) b_hn_0_q0<=mem_b_hn_0[dut.b_hn_0_address0];
if(dut.b_hn_0_ce1) b_hn_0_q1<=mem_b_hn_0[dut.b_hn_0_address1];
if(dut.b_hn_1_ce0) b_hn_1_q0<=mem_b_hn_1[dut.b_hn_1_address0];
if(dut.b_hn_1_ce1) b_hn_1_q1<=mem_b_hn_1[dut.b_hn_1_address1];
if(dut.b_hn_2_ce0) b_hn_2_q0<=mem_b_hn_2[dut.b_hn_2_address0];
if(dut.b_hn_2_ce1) b_hn_2_q1<=mem_b_hn_2[dut.b_hn_2_address1];
if(dut.IQ_seq_ce0) IQ_seq_q0<=iq[(reads/128)*128+dut.IQ_seq_address0];
if(dut.gating_params_ce0) gating_params_q0<=gate[dut.gating_params_address0];
if(dut.OUT_seq_ce0 && dut.OUT_seq_we0)begin if((^dut.OUT_seq_d0)===1'bx)$fatal;$display("WRITE %d 0 %d %d",cycle,dut.OUT_seq_address0,dut.OUT_seq_d0);writes=writes+1;end
if(dut.IQ_seq_ce1) IQ_seq_q1<=iq[(reads/128)*128+dut.IQ_seq_address1];
if(dut.gating_params_ce1) gating_params_q1<=gate[dut.gating_params_address1];
if(dut.OUT_seq_ce1 && dut.OUT_seq_we1)begin if((^dut.OUT_seq_d1)===1'bx)$fatal;$display("WRITE %d 1 %d %d",cycle,dut.OUT_seq_address1,dut.OUT_seq_d1);writes=writes+1;end
reads=reads+dut.IQ_seq_ce0+dut.IQ_seq_ce1;
if(start && dut.ap_ready)begin accepted=accepted+1;weight<=weight+101;seg<=(accepted%40==0);if(accepted==120)start<=0;end
if(dut.fifo_shared_1_8_push) begin

finished_push=finished_push+1;end
if(dut.ap_done)begin $display("DONE %d",cycle);finished=finished+1;end
if(finished==120)begin if(writes!=15360 || finished_push!=120 || reads!=15360)$fatal;$finish;end
if(cycle>40000)$fatal;
end

endmodule
