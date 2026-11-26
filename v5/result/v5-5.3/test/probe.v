`timescale 1ns/1ps
module probe;
reg clk=0,rst=1,start=0,seg=0;reg [13:0] weight=0;
always #5 clk=~clk;
reg [14:0] iq[0:15359];reg [13:0] gate[0:2];
integer finished_push=0;integer cycle=0,accepted=0,finished=0,writes=0,reads=0;
initial begin $readmemh("iq.hex",iq);$readmemh("gate.hex",gate);repeat(4) @(negedge clk);weight=101;seg=1;rst=0;start=1;end
reg [14:0] b_ir_0_q0=0;
reg [14:0] mem_b_ir_0[0:4]; initial begin mem_b_ir_0[0]=15'd32673;mem_b_ir_0[1]=15'd3964;mem_b_ir_0[2]=15'd645;mem_b_ir_0[3]=15'd2689;mem_b_ir_0[4]=15'd2170;end
reg [14:0] b_ir_0_q1=0;
reg [14:0] b_ir_1_q0=0;
reg [14:0] mem_b_ir_1[0:4]; initial begin mem_b_ir_1[0]=15'd31;mem_b_ir_1[1]=15'd1217;mem_b_ir_1[2]=15'd32699;mem_b_ir_1[3]=15'd470;mem_b_ir_1[4]=15'd1213;end
reg [14:0] b_ir_1_q1=0;
reg [14:0] b_ir_2_q0=0;
reg [14:0] mem_b_ir_2[0:4]; initial begin mem_b_ir_2[0]=15'd772;mem_b_ir_2[1]=15'd2382;mem_b_ir_2[2]=15'd4087;mem_b_ir_2[3]=15'd31898;mem_b_ir_2[4]=15'd2933;end
reg [14:0] b_ir_2_q1=0;
reg [14:0] b_hr_0_q0=0;
reg [14:0] mem_b_hr_0[0:4]; initial begin mem_b_hr_0[0]=15'd765;mem_b_hr_0[1]=15'd2364;mem_b_hr_0[2]=15'd625;mem_b_hr_0[3]=15'd2530;mem_b_hr_0[4]=15'd624;end
reg [14:0] b_hr_0_q1=0;
reg [14:0] b_hr_1_q0=0;
reg [14:0] mem_b_hr_1[0:4]; initial begin mem_b_hr_1[0]=15'd178;mem_b_hr_1[1]=15'd414;mem_b_hr_1[2]=15'd235;mem_b_hr_1[3]=15'd414;mem_b_hr_1[4]=15'd11;end
reg [14:0] b_hr_1_q1=0;
reg [14:0] b_hr_2_q0=0;
reg [14:0] mem_b_hr_2[0:4]; initial begin mem_b_hr_2[0]=15'd818;mem_b_hr_2[1]=15'd2361;mem_b_hr_2[2]=15'd3439;mem_b_hr_2[3]=15'd31904;mem_b_hr_2[4]=15'd3650;end
reg [14:0] b_hr_2_q1=0;
reg [14:0] b_iz_0_q0=0;
reg [14:0] mem_b_iz_0[0:4]; initial begin mem_b_iz_0[0]=15'd31910;mem_b_iz_0[1]=15'd348;mem_b_iz_0[2]=15'd29763;mem_b_iz_0[3]=15'd31112;mem_b_iz_0[4]=15'd30273;end
reg [14:0] b_iz_0_q1=0;
reg [14:0] b_iz_1_q0=0;
reg [14:0] mem_b_iz_1[0:4]; initial begin mem_b_iz_1[0]=15'd29916;mem_b_iz_1[1]=15'd30648;mem_b_iz_1[2]=15'd30741;mem_b_iz_1[3]=15'd30634;mem_b_iz_1[4]=15'd29124;end
reg [14:0] b_iz_1_q1=0;
reg [14:0] b_iz_2_q0=0;
reg [14:0] mem_b_iz_2[0:4]; initial begin mem_b_iz_2[0]=15'd32358;mem_b_iz_2[1]=15'd31821;mem_b_iz_2[2]=15'd30862;mem_b_iz_2[3]=15'd31242;mem_b_iz_2[4]=15'd32075;end
reg [14:0] b_iz_2_q1=0;
reg [14:0] b_hz_0_q0=0;
reg [14:0] mem_b_hz_0[0:4]; initial begin mem_b_hz_0[0]=15'd30671;mem_b_hz_0[1]=15'd32128;mem_b_hz_0[2]=15'd30835;mem_b_hz_0[3]=15'd30093;mem_b_hz_0[4]=15'd31083;end
reg [14:0] b_hz_0_q1=0;
reg [14:0] b_hz_1_q0=0;
reg [14:0] mem_b_hz_1[0:4]; initial begin mem_b_hz_1[0]=15'd31075;mem_b_hz_1[1]=15'd31242;mem_b_hz_1[2]=15'd30060;mem_b_hz_1[3]=15'd30201;mem_b_hz_1[4]=15'd31269;end
reg [14:0] b_hz_1_q1=0;
reg [14:0] b_hz_2_q0=0;
reg [14:0] mem_b_hz_2[0:4]; initial begin mem_b_hz_2[0]=15'd32049;mem_b_hz_2[1]=15'd32363;mem_b_hz_2[2]=15'd31450;mem_b_hz_2[3]=15'd31489;mem_b_hz_2[4]=15'd31843;end
reg [14:0] b_hz_2_q1=0;
reg [14:0] b_in_0_q0=0;
reg [14:0] mem_b_in_0[0:4]; initial begin mem_b_in_0[0]=15'd808;mem_b_in_0[1]=15'd73;mem_b_in_0[2]=15'd711;mem_b_in_0[3]=15'd31876;mem_b_in_0[4]=15'd457;end
reg [14:0] b_in_0_q1=0;
reg [14:0] b_in_1_q0=0;
reg [14:0] mem_b_in_1[0:4]; initial begin mem_b_in_1[0]=15'd32661;mem_b_in_1[1]=15'd386;mem_b_in_1[2]=15'd32425;mem_b_in_1[3]=15'd526;mem_b_in_1[4]=15'd32380;end
reg [14:0] b_in_1_q1=0;
reg [14:0] b_in_2_q0=0;
reg [14:0] mem_b_in_2[0:4]; initial begin mem_b_in_2[0]=15'd32514;mem_b_in_2[1]=15'd32703;mem_b_in_2[2]=15'd32735;mem_b_in_2[3]=15'd76;mem_b_in_2[4]=15'd32572;end
reg [14:0] b_in_2_q1=0;
reg [14:0] b_hn_0_q0=0;
reg [14:0] mem_b_hn_0[0:4]; initial begin mem_b_hn_0[0]=15'd342;mem_b_hn_0[1]=15'd22;mem_b_hn_0[2]=15'd876;mem_b_hn_0[3]=15'd31981;mem_b_hn_0[4]=15'd428;end
reg [14:0] b_hn_0_q1=0;
reg [14:0] b_hn_1_q0=0;
reg [14:0] mem_b_hn_1[0:4]; initial begin mem_b_hn_1[0]=15'd21;mem_b_hn_1[1]=15'd318;mem_b_hn_1[2]=15'd32279;mem_b_hn_1[3]=15'd583;mem_b_hn_1[4]=15'd32364;end
reg [14:0] b_hn_1_q1=0;
reg [14:0] b_hn_2_q0=0;
reg [14:0] mem_b_hn_2[0:4]; initial begin mem_b_hn_2[0]=15'd32378;mem_b_hn_2[1]=15'd32662;mem_b_hn_2[2]=15'd32676;mem_b_hn_2[3]=15'd87;mem_b_hn_2[4]=15'd32502;end
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
.W_inj_3_1(14'd15397),
.W_inj_3_2(14'd16360),
.W_inj_3_3(14'd39),
.W_inj_3_4(14'd16326),
.W_inj_3_5(14'd2),
.W_inj_4_0(14'd146),
.W_inj_4_1(14'd15909),
.W_inj_4_2(14'd91),
.W_inj_4_3(14'd1617),
.W_inj_4_4(14'd16340),
.W_inj_4_5(14'd17),
.b_inj_0(15'd32711),
.b_inj_1(15'd32709),
.b_inj_2(15'd32748),
.b_inj_3(15'd32206),
.b_inj_4(15'd32295),
.prelu_param(14'd1039),
.gating_params_q0(gating_params_q0),
.gating_params_q1(gating_params_q1),
.W_ir_0_0_0(14'd14924),
.W_ir_0_0_1(14'd15998),
.W_ir_0_0_2(14'd387),
.W_ir_0_0_3(14'd14602),
.W_ir_0_0_4(14'd15882),
.W_ir_0_1_0(14'd751),
.W_ir_0_1_1(14'd665),
.W_ir_0_1_2(14'd15761),
.W_ir_0_1_3(14'd16289),
.W_ir_0_1_4(14'd14971),
.W_ir_0_2_0(14'd177),
.W_ir_0_2_1(14'd16106),
.W_ir_0_2_2(14'd15950),
.W_ir_0_2_3(14'd15875),
.W_ir_0_2_4(14'd434),
.W_ir_0_3_0(14'd418),
.W_ir_0_3_1(14'd77),
.W_ir_0_3_2(14'd15879),
.W_ir_0_3_3(14'd16129),
.W_ir_0_3_4(14'd15355),
.W_ir_0_4_0(14'd15010),
.W_ir_0_4_1(14'd936),
.W_ir_0_4_2(14'd667),
.W_ir_0_4_3(14'd15762),
.W_ir_0_4_4(14'd241),
.W_ir_1_0_0(14'd15784),
.W_ir_1_0_1(14'd15550),
.W_ir_1_0_2(14'd16091),
.W_ir_1_0_3(14'd188),
.W_ir_1_0_4(14'd808),
.W_ir_1_1_0(14'd2),
.W_ir_1_1_1(14'd299),
.W_ir_1_1_2(14'd15215),
.W_ir_1_1_3(14'd237),
.W_ir_1_1_4(14'd15468),
.W_ir_1_2_0(14'd217),
.W_ir_1_2_1(14'd687),
.W_ir_1_2_2(14'd826),
.W_ir_1_2_3(14'd15968),
.W_ir_1_2_4(14'd15751),
.W_ir_1_3_0(14'd16224),
.W_ir_1_3_1(14'd635),
.W_ir_1_3_2(14'd15846),
.W_ir_1_3_3(14'd131),
.W_ir_1_3_4(14'd15518),
.W_ir_1_4_0(14'd15526),
.W_ir_1_4_1(14'd97),
.W_ir_1_4_2(14'd152),
.W_ir_1_4_3(14'd553),
.W_ir_1_4_4(14'd3862),
.W_ir_2_0_0(14'd0),
.W_ir_2_0_1(14'd0),
.W_ir_2_0_2(14'd0),
.W_ir_2_0_3(14'd0),
.W_ir_2_0_4(14'd0),
.W_ir_2_1_0(14'd0),
.W_ir_2_1_1(14'd0),
.W_ir_2_1_2(14'd0),
.W_ir_2_1_3(14'd0),
.W_ir_2_1_4(14'd0),
.W_ir_2_2_0(14'd0),
.W_ir_2_2_1(14'd0),
.W_ir_2_2_2(14'd0),
.W_ir_2_2_3(14'd0),
.W_ir_2_2_4(14'd0),
.W_ir_2_3_0(14'd0),
.W_ir_2_3_1(14'd0),
.W_ir_2_3_2(14'd0),
.W_ir_2_3_3(14'd0),
.W_ir_2_3_4(14'd0),
.W_ir_2_4_0(14'd0),
.W_ir_2_4_1(14'd0),
.W_ir_2_4_2(14'd0),
.W_ir_2_4_3(14'd0),
.W_ir_2_4_4(14'd0),
.W_iz_0_0_0(14'd16347),
.W_iz_0_0_1(14'd431),
.W_iz_0_0_2(14'd16147),
.W_iz_0_0_3(14'd505),
.W_iz_0_0_4(14'd16003),
.W_iz_0_1_0(14'd77),
.W_iz_0_1_1(14'd16202),
.W_iz_0_1_2(14'd16004),
.W_iz_0_1_3(14'd246),
.W_iz_0_1_4(14'd15245),
.W_iz_0_2_0(14'd38),
.W_iz_0_2_1(14'd274),
.W_iz_0_2_2(14'd278),
.W_iz_0_2_3(14'd16312),
.W_iz_0_2_4(14'd16379),
.W_iz_0_3_0(14'd666),
.W_iz_0_3_1(14'd377),
.W_iz_0_3_2(14'd15540),
.W_iz_0_3_3(14'd16064),
.W_iz_0_3_4(14'd15942),
.W_iz_0_4_0(14'd16152),
.W_iz_0_4_1(14'd16299),
.W_iz_0_4_2(14'd15947),
.W_iz_0_4_3(14'd15857),
.W_iz_0_4_4(14'd15656),
.W_iz_1_0_0(14'd16285),
.W_iz_1_0_1(14'd23),
.W_iz_1_0_2(14'd3),
.W_iz_1_0_3(14'd15827),
.W_iz_1_0_4(14'd16171),
.W_iz_1_1_0(14'd382),
.W_iz_1_1_1(14'd16379),
.W_iz_1_1_2(14'd16267),
.W_iz_1_1_3(14'd16143),
.W_iz_1_1_4(14'd15819),
.W_iz_1_2_0(14'd470),
.W_iz_1_2_1(14'd6),
.W_iz_1_2_2(14'd918),
.W_iz_1_2_3(14'd1307),
.W_iz_1_2_4(14'd15956),
.W_iz_1_3_0(14'd16032),
.W_iz_1_3_1(14'd1304),
.W_iz_1_3_2(14'd15769),
.W_iz_1_3_3(14'd16037),
.W_iz_1_3_4(14'd15538),
.W_iz_1_4_0(14'd15058),
.W_iz_1_4_1(14'd15318),
.W_iz_1_4_2(14'd893),
.W_iz_1_4_3(14'd15814),
.W_iz_1_4_4(14'd652),
.W_iz_2_0_0(14'd0),
.W_iz_2_0_1(14'd0),
.W_iz_2_0_2(14'd0),
.W_iz_2_0_3(14'd0),
.W_iz_2_0_4(14'd0),
.W_iz_2_1_0(14'd0),
.W_iz_2_1_1(14'd0),
.W_iz_2_1_2(14'd0),
.W_iz_2_1_3(14'd0),
.W_iz_2_1_4(14'd0),
.W_iz_2_2_0(14'd0),
.W_iz_2_2_1(14'd0),
.W_iz_2_2_2(14'd0),
.W_iz_2_2_3(14'd0),
.W_iz_2_2_4(14'd0),
.W_iz_2_3_0(14'd0),
.W_iz_2_3_1(14'd0),
.W_iz_2_3_2(14'd0),
.W_iz_2_3_3(14'd0),
.W_iz_2_3_4(14'd0),
.W_iz_2_4_0(14'd0),
.W_iz_2_4_1(14'd0),
.W_iz_2_4_2(14'd0),
.W_iz_2_4_3(14'd0),
.W_iz_2_4_4(14'd0),
.W_in_0_0_0(14'd46),
.W_in_0_0_1(14'd140),
.W_in_0_0_2(14'd16198),
.W_in_0_0_3(14'd16003),
.W_in_0_0_4(14'd78),
.W_in_0_1_0(14'd208),
.W_in_0_1_1(14'd116),
.W_in_0_1_2(14'd232),
.W_in_0_1_3(14'd309),
.W_in_0_1_4(14'd121),
.W_in_0_2_0(14'd125),
.W_in_0_2_1(14'd476),
.W_in_0_2_2(14'd15912),
.W_in_0_2_3(14'd16275),
.W_in_0_2_4(14'd228),
.W_in_0_3_0(14'd287),
.W_in_0_3_1(14'd347),
.W_in_0_3_2(14'd15999),
.W_in_0_3_3(14'd16103),
.W_in_0_3_4(14'd347),
.W_in_0_4_0(14'd20),
.W_in_0_4_1(14'd16349),
.W_in_0_4_2(14'd285),
.W_in_0_4_3(14'd16301),
.W_in_0_4_4(14'd158),
.W_in_1_0_0(14'd16164),
.W_in_1_0_1(14'd15943),
.W_in_1_0_2(14'd16341),
.W_in_1_0_3(14'd16205),
.W_in_1_0_4(14'd16188),
.W_in_1_1_0(14'd16043),
.W_in_1_1_1(14'd302),
.W_in_1_1_2(14'd187),
.W_in_1_1_3(14'd16191),
.W_in_1_1_4(14'd99),
.W_in_1_2_0(14'd16216),
.W_in_1_2_1(14'd17),
.W_in_1_2_2(14'd16247),
.W_in_1_2_3(14'd416),
.W_in_1_2_4(14'd16343),
.W_in_1_3_0(14'd369),
.W_in_1_3_1(14'd14),
.W_in_1_3_2(14'd117),
.W_in_1_3_3(14'd156),
.W_in_1_3_4(14'd64),
.W_in_1_4_0(14'd120),
.W_in_1_4_1(14'd115),
.W_in_1_4_2(14'd16313),
.W_in_1_4_3(14'd7),
.W_in_1_4_4(14'd16045),
.W_in_2_0_0(14'd52),
.W_in_2_0_1(14'd22),
.W_in_2_0_2(14'd16309),
.W_in_2_0_3(14'd15929),
.W_in_2_0_4(14'd71),
.W_in_2_1_0(14'd16092),
.W_in_2_1_1(14'd327),
.W_in_2_1_2(14'd16294),
.W_in_2_1_3(14'd16220),
.W_in_2_1_4(14'd216),
.W_in_2_2_0(14'd77),
.W_in_2_2_1(14'd26),
.W_in_2_2_2(14'd16074),
.W_in_2_2_3(14'd257),
.W_in_2_2_4(14'd16359),
.W_in_2_3_0(14'd133),
.W_in_2_3_1(14'd16136),
.W_in_2_3_2(14'd16196),
.W_in_2_3_3(14'd200),
.W_in_2_3_4(14'd94),
.W_in_2_4_0(14'd152),
.W_in_2_4_1(14'd16208),
.W_in_2_4_2(14'd15866),
.W_in_2_4_3(14'd16062),
.W_in_2_4_4(14'd16345),
.W_hn_0_0_0(14'd16050),
.W_hn_0_0_1(14'd16311),
.W_hn_0_0_2(14'd16141),
.W_hn_0_0_3(14'd416),
.W_hn_0_0_4(14'd16345),
.W_hn_0_1_0(14'd452),
.W_hn_0_1_1(14'd15446),
.W_hn_0_1_2(14'd16323),
.W_hn_0_1_3(14'd365),
.W_hn_0_1_4(14'd16307),
.W_hn_0_2_0(14'd16063),
.W_hn_0_2_1(14'd16266),
.W_hn_0_2_2(14'd175),
.W_hn_0_2_3(14'd16224),
.W_hn_0_2_4(14'd178),
.W_hn_0_3_0(14'd16327),
.W_hn_0_3_1(14'd16340),
.W_hn_0_3_2(14'd16086),
.W_hn_0_3_3(14'd15922),
.W_hn_0_3_4(14'd16240),
.W_hn_0_4_0(14'd16258),
.W_hn_0_4_1(14'd15930),
.W_hn_0_4_2(14'd15903),
.W_hn_0_4_3(14'd16164),
.W_hn_0_4_4(14'd16287),
.W_hn_1_0_0(14'd30),
.W_hn_1_0_1(14'd16355),
.W_hn_1_0_2(14'd15774),
.W_hn_1_0_3(14'd16308),
.W_hn_1_0_4(14'd15979),
.W_hn_1_1_0(14'd376),
.W_hn_1_1_1(14'd15875),
.W_hn_1_1_2(14'd176),
.W_hn_1_1_3(14'd140),
.W_hn_1_1_4(14'd16183),
.W_hn_1_2_0(14'd183),
.W_hn_1_2_1(14'd16307),
.W_hn_1_2_2(14'd16030),
.W_hn_1_2_3(14'd200),
.W_hn_1_2_4(14'd16070),
.W_hn_1_3_0(14'd191),
.W_hn_1_3_1(14'd420),
.W_hn_1_3_2(14'd16346),
.W_hn_1_3_3(14'd16078),
.W_hn_1_3_4(14'd16370),
.W_hn_1_4_0(14'd16270),
.W_hn_1_4_1(14'd446),
.W_hn_1_4_2(14'd479),
.W_hn_1_4_3(14'd334),
.W_hn_1_4_4(14'd16017),
.W_hn_2_0_0(14'd16324),
.W_hn_2_0_1(14'd448),
.W_hn_2_0_2(14'd1146),
.W_hn_2_0_3(14'd16102),
.W_hn_2_0_4(14'd15856),
.W_hn_2_1_0(14'd15872),
.W_hn_2_1_1(14'd160),
.W_hn_2_1_2(14'd72),
.W_hn_2_1_3(14'd192),
.W_hn_2_1_4(14'd691),
.W_hn_2_2_0(14'd16007),
.W_hn_2_2_1(14'd640),
.W_hn_2_2_2(14'd675),
.W_hn_2_2_3(14'd16264),
.W_hn_2_2_4(14'd508),
.W_hn_2_3_0(14'd112),
.W_hn_2_3_1(14'd240),
.W_hn_2_3_2(14'd16260),
.W_hn_2_3_3(14'd16254),
.W_hn_2_3_4(14'd86),
.W_hn_2_4_0(14'd15600),
.W_hn_2_4_1(14'd14),
.W_hn_2_4_2(14'd15430),
.W_hn_2_4_3(14'd16136),
.W_hn_2_4_4(14'd16108),
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

if(dut.ap_done)begin $display("DONE %d",cycle);finished=finished+1;end
if(finished==120)begin if(writes!=15360 || reads!=15360)$fatal;$finish;end
if(cycle>40000)$fatal;
end

endmodule
