`timescale 1ns/1ps
module probe;
reg clk=0,rst=1,start=0,seg=0;reg [13:0] weight=0;
always #5 clk=~clk;
reg [14:0] iq[0:15359];reg [13:0] gate[0:2];
integer finished_push=0;integer cycle=0,accepted=0,finished=0,writes=0,reads=0;
initial begin $readmemh("iq.hex",iq);$readmemh("gate.hex",gate);repeat(4) @(negedge clk);weight=101;seg=1;rst=0;start=1;end
reg [14:0] b_ir_0_q0=0;
reg [14:0] mem_b_ir_0[0:4]; initial begin mem_b_ir_0[0]=15'd1253;mem_b_ir_0[1]=15'd4245;mem_b_ir_0[2]=15'd976;mem_b_ir_0[3]=15'd2614;mem_b_ir_0[4]=15'd774;end
reg [14:0] b_ir_0_q1=0;
reg [14:0] b_ir_1_q0=0;
reg [14:0] mem_b_ir_1[0:4]; initial begin mem_b_ir_1[0]=15'd1056;mem_b_ir_1[1]=15'd431;mem_b_ir_1[2]=15'd181;mem_b_ir_1[3]=15'd554;mem_b_ir_1[4]=15'd1591;end
reg [14:0] b_ir_1_q1=0;
reg [14:0] b_ir_2_q0=0;
reg [14:0] mem_b_ir_2[0:4]; initial begin mem_b_ir_2[0]=15'd755;mem_b_ir_2[1]=15'd2485;mem_b_ir_2[2]=15'd4312;mem_b_ir_2[3]=15'd32161;mem_b_ir_2[4]=15'd3265;end
reg [14:0] b_ir_2_q1=0;
reg [14:0] b_hr_0_q0=0;
reg [14:0] mem_b_hr_0[0:4]; initial begin mem_b_hr_0[0]=15'd765;mem_b_hr_0[1]=15'd2367;mem_b_hr_0[2]=15'd625;mem_b_hr_0[3]=15'd2530;mem_b_hr_0[4]=15'd625;end
reg [14:0] b_hr_0_q1=0;
reg [14:0] b_hr_1_q0=0;
reg [14:0] mem_b_hr_1[0:4]; initial begin mem_b_hr_1[0]=15'd178;mem_b_hr_1[1]=15'd415;mem_b_hr_1[2]=15'd236;mem_b_hr_1[3]=15'd413;mem_b_hr_1[4]=15'd12;end
reg [14:0] b_hr_1_q1=0;
reg [14:0] b_hr_2_q0=0;
reg [14:0] mem_b_hr_2[0:4]; initial begin mem_b_hr_2[0]=15'd816;mem_b_hr_2[1]=15'd2363;mem_b_hr_2[2]=15'd3440;mem_b_hr_2[3]=15'd31904;mem_b_hr_2[4]=15'd3648;end
reg [14:0] b_hr_2_q1=0;
reg [14:0] b_iz_0_q0=0;
reg [14:0] mem_b_iz_0[0:4]; initial begin mem_b_iz_0[0]=15'd1225;mem_b_iz_0[1]=15'd773;mem_b_iz_0[2]=15'd32527;mem_b_iz_0[3]=15'd31134;mem_b_iz_0[4]=15'd32579;end
reg [14:0] b_iz_0_q1=0;
reg [14:0] b_iz_1_q0=0;
reg [14:0] mem_b_iz_1[0:4]; initial begin mem_b_iz_1[0]=15'd30391;mem_b_iz_1[1]=15'd29822;mem_b_iz_1[2]=15'd30623;mem_b_iz_1[3]=15'd29815;mem_b_iz_1[4]=15'd30105;end
reg [14:0] b_iz_1_q1=0;
reg [14:0] b_iz_2_q0=0;
reg [14:0] mem_b_iz_2[0:4]; initial begin mem_b_iz_2[0]=15'd32251;mem_b_iz_2[1]=15'd31998;mem_b_iz_2[2]=15'd30101;mem_b_iz_2[3]=15'd32131;mem_b_iz_2[4]=15'd31866;end
reg [14:0] b_iz_2_q1=0;
reg [14:0] b_hz_0_q0=0;
reg [14:0] mem_b_hz_0[0:4]; initial begin mem_b_hz_0[0]=15'd30671;mem_b_hz_0[1]=15'd32125;mem_b_hz_0[2]=15'd30834;mem_b_hz_0[3]=15'd30096;mem_b_hz_0[4]=15'd31082;end
reg [14:0] b_hz_0_q1=0;
reg [14:0] b_hz_1_q0=0;
reg [14:0] mem_b_hz_1[0:4]; initial begin mem_b_hz_1[0]=15'd31077;mem_b_hz_1[1]=15'd31242;mem_b_hz_1[2]=15'd30060;mem_b_hz_1[3]=15'd30202;mem_b_hz_1[4]=15'd31266;end
reg [14:0] b_hz_1_q1=0;
reg [14:0] b_hz_2_q0=0;
reg [14:0] mem_b_hz_2[0:4]; initial begin mem_b_hz_2[0]=15'd32052;mem_b_hz_2[1]=15'd32363;mem_b_hz_2[2]=15'd31450;mem_b_hz_2[3]=15'd31491;mem_b_hz_2[4]=15'd31841;end
reg [14:0] b_hz_2_q1=0;
reg [14:0] b_in_0_q0=0;
reg [14:0] mem_b_in_0[0:4]; initial begin mem_b_in_0[0]=15'd675;mem_b_in_0[1]=15'd33;mem_b_in_0[2]=15'd597;mem_b_in_0[3]=15'd31962;mem_b_in_0[4]=15'd274;end
reg [14:0] b_in_0_q1=0;
reg [14:0] b_in_1_q0=0;
reg [14:0] mem_b_in_1[0:4]; initial begin mem_b_in_1[0]=15'd32739;mem_b_in_1[1]=15'd295;mem_b_in_1[2]=15'd32521;mem_b_in_1[3]=15'd371;mem_b_in_1[4]=15'd32727;end
reg [14:0] b_in_1_q1=0;
reg [14:0] b_in_2_q0=0;
reg [14:0] mem_b_in_2[0:4]; initial begin mem_b_in_2[0]=15'd32407;mem_b_in_2[1]=15'd12;mem_b_in_2[2]=15'd32746;mem_b_in_2[3]=15'd128;mem_b_in_2[4]=15'd32407;end
reg [14:0] b_in_2_q1=0;
reg [14:0] b_hn_0_q0=0;
reg [14:0] mem_b_hn_0[0:4]; initial begin mem_b_hn_0[0]=15'd366;mem_b_hn_0[1]=15'd27;mem_b_hn_0[2]=15'd743;mem_b_hn_0[3]=15'd32024;mem_b_hn_0[4]=15'd315;end
reg [14:0] b_hn_0_q1=0;
reg [14:0] b_hn_1_q0=0;
reg [14:0] mem_b_hn_1[0:4]; initial begin mem_b_hn_1[0]=15'd141;mem_b_hn_1[1]=15'd132;mem_b_hn_1[2]=15'd32379;mem_b_hn_1[3]=15'd448;mem_b_hn_1[4]=15'd32506;end
reg [14:0] b_hn_1_q1=0;
reg [14:0] b_hn_2_q0=0;
reg [14:0] mem_b_hn_2[0:4]; initial begin mem_b_hn_2[0]=15'd32264;mem_b_hn_2[1]=15'd32737;mem_b_hn_2[2]=15'd32683;mem_b_hn_2[3]=15'd138;mem_b_hn_2[4]=15'd32334;end
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
.W_ir_0_0_0(14'd15426),
.W_ir_0_0_1(14'd72),
.W_ir_0_0_2(14'd923),
.W_ir_0_0_3(14'd14778),
.W_ir_0_0_4(14'd15707),
.W_ir_0_1_0(14'd1105),
.W_ir_0_1_1(14'd538),
.W_ir_0_1_2(14'd15847),
.W_ir_0_1_3(14'd108),
.W_ir_0_1_4(14'd15275),
.W_ir_0_2_0(14'd16175),
.W_ir_0_2_1(14'd16359),
.W_ir_0_2_2(14'd16319),
.W_ir_0_2_3(14'd16053),
.W_ir_0_2_4(14'd226),
.W_ir_0_3_0(14'd716),
.W_ir_0_3_1(14'd405),
.W_ir_0_3_2(14'd15827),
.W_ir_0_3_3(14'd16148),
.W_ir_0_3_4(14'd15420),
.W_ir_0_4_0(14'd881),
.W_ir_0_4_1(14'd442),
.W_ir_0_4_2(14'd16023),
.W_ir_0_4_3(14'd15840),
.W_ir_0_4_4(14'd15467),
.W_ir_1_0_0(14'd15506),
.W_ir_1_0_1(14'd15938),
.W_ir_1_0_2(14'd15740),
.W_ir_1_0_3(14'd15945),
.W_ir_1_0_4(14'd675),
.W_ir_1_1_0(14'd12),
.W_ir_1_1_1(14'd322),
.W_ir_1_1_2(14'd15268),
.W_ir_1_1_3(14'd210),
.W_ir_1_1_4(14'd15810),
.W_ir_1_2_0(14'd615),
.W_ir_1_2_1(14'd87),
.W_ir_1_2_2(14'd529),
.W_ir_1_2_3(14'd207),
.W_ir_1_2_4(14'd16091),
.W_ir_1_3_0(14'd258),
.W_ir_1_3_1(14'd699),
.W_ir_1_3_2(14'd15695),
.W_ir_1_3_3(14'd8),
.W_ir_1_3_4(14'd15560),
.W_ir_1_4_0(14'd15106),
.W_ir_1_4_1(14'd1365),
.W_ir_1_4_2(14'd14783),
.W_ir_1_4_3(14'd15918),
.W_ir_1_4_4(14'd3234),
.W_ir_2_0_0(14'd16267),
.W_ir_2_0_1(14'd498),
.W_ir_2_0_2(14'd16060),
.W_ir_2_0_3(14'd511),
.W_ir_2_0_4(14'd13988),
.W_ir_2_1_0(14'd360),
.W_ir_2_1_1(14'd839),
.W_ir_2_1_2(14'd15043),
.W_ir_2_1_3(14'd277),
.W_ir_2_1_4(14'd14325),
.W_ir_2_2_0(14'd42),
.W_ir_2_2_1(14'd631),
.W_ir_2_2_2(14'd15819),
.W_ir_2_2_3(14'd16245),
.W_ir_2_2_4(14'd465),
.W_ir_2_3_0(14'd15796),
.W_ir_2_3_1(14'd74),
.W_ir_2_3_2(14'd550),
.W_ir_2_3_3(14'd617),
.W_ir_2_3_4(14'd13471),
.W_ir_2_4_0(14'd240),
.W_ir_2_4_1(14'd1169),
.W_ir_2_4_2(14'd14634),
.W_ir_2_4_3(14'd1093),
.W_ir_2_4_4(14'd10164),
.W_iz_0_0_0(14'd136),
.W_iz_0_0_1(14'd202),
.W_iz_0_0_2(14'd16341),
.W_iz_0_0_3(14'd64),
.W_iz_0_0_4(14'd16235),
.W_iz_0_1_0(14'd16290),
.W_iz_0_1_1(14'd15902),
.W_iz_0_1_2(14'd18),
.W_iz_0_1_3(14'd251),
.W_iz_0_1_4(14'd15643),
.W_iz_0_2_0(14'd515),
.W_iz_0_2_1(14'd339),
.W_iz_0_2_2(14'd16208),
.W_iz_0_2_3(14'd16178),
.W_iz_0_2_4(14'd315),
.W_iz_0_3_0(14'd649),
.W_iz_0_3_1(14'd187),
.W_iz_0_3_2(14'd15992),
.W_iz_0_3_3(14'd16383),
.W_iz_0_3_4(14'd16058),
.W_iz_0_4_0(14'd496),
.W_iz_0_4_1(14'd230),
.W_iz_0_4_2(14'd15976),
.W_iz_0_4_3(14'd16283),
.W_iz_0_4_4(14'd16),
.W_iz_1_0_0(14'd249),
.W_iz_1_0_1(14'd15295),
.W_iz_1_0_2(14'd1182),
.W_iz_1_0_3(14'd502),
.W_iz_1_0_4(14'd15768),
.W_iz_1_1_0(14'd996),
.W_iz_1_1_1(14'd16021),
.W_iz_1_1_2(14'd506),
.W_iz_1_1_3(14'd611),
.W_iz_1_1_4(14'd16216),
.W_iz_1_2_0(14'd15974),
.W_iz_1_2_1(14'd16221),
.W_iz_1_2_2(14'd792),
.W_iz_1_2_3(14'd1092),
.W_iz_1_2_4(14'd154),
.W_iz_1_3_0(14'd36),
.W_iz_1_3_1(14'd1220),
.W_iz_1_3_2(14'd15941),
.W_iz_1_3_3(14'd16312),
.W_iz_1_3_4(14'd16360),
.W_iz_1_4_0(14'd15271),
.W_iz_1_4_1(14'd15664),
.W_iz_1_4_2(14'd493),
.W_iz_1_4_3(14'd268),
.W_iz_1_4_4(14'd1155),
.W_iz_2_0_0(14'd378),
.W_iz_2_0_1(14'd400),
.W_iz_2_0_2(14'd512),
.W_iz_2_0_3(14'd255),
.W_iz_2_0_4(14'd15342),
.W_iz_2_1_0(14'd139),
.W_iz_2_1_1(14'd617),
.W_iz_2_1_2(14'd16024),
.W_iz_2_1_3(14'd44),
.W_iz_2_1_4(14'd14452),
.W_iz_2_2_0(14'd57),
.W_iz_2_2_1(14'd247),
.W_iz_2_2_2(14'd15731),
.W_iz_2_2_3(14'd685),
.W_iz_2_2_4(14'd15188),
.W_iz_2_3_0(14'd16311),
.W_iz_2_3_1(14'd15924),
.W_iz_2_3_2(14'd1338),
.W_iz_2_3_3(14'd254),
.W_iz_2_3_4(14'd13969),
.W_iz_2_4_0(14'd16123),
.W_iz_2_4_1(14'd173),
.W_iz_2_4_2(14'd15655),
.W_iz_2_4_3(14'd16086),
.W_iz_2_4_4(14'd14298),
.W_in_0_0_0(14'd161),
.W_in_0_0_1(14'd92),
.W_in_0_0_2(14'd16208),
.W_in_0_0_3(14'd15885),
.W_in_0_0_4(14'd125),
.W_in_0_1_0(14'd285),
.W_in_0_1_1(14'd34),
.W_in_0_1_2(14'd243),
.W_in_0_1_3(14'd279),
.W_in_0_1_4(14'd164),
.W_in_0_2_0(14'd16379),
.W_in_0_2_1(14'd419),
.W_in_0_2_2(14'd15935),
.W_in_0_2_3(14'd16369),
.W_in_0_2_4(14'd94),
.W_in_0_3_0(14'd284),
.W_in_0_3_1(14'd351),
.W_in_0_3_2(14'd15960),
.W_in_0_3_3(14'd16174),
.W_in_0_3_4(14'd333),
.W_in_0_4_0(14'd61),
.W_in_0_4_1(14'd16278),
.W_in_0_4_2(14'd238),
.W_in_0_4_3(14'd16182),
.W_in_0_4_4(14'd66),
.W_in_1_0_0(14'd16228),
.W_in_1_0_1(14'd15840),
.W_in_1_0_2(14'd16369),
.W_in_1_0_3(14'd16198),
.W_in_1_0_4(14'd16221),
.W_in_1_1_0(14'd16117),
.W_in_1_1_1(14'd348),
.W_in_1_1_2(14'd260),
.W_in_1_1_3(14'd16167),
.W_in_1_1_4(14'd64),
.W_in_1_2_0(14'd16233),
.W_in_1_2_1(14'd18),
.W_in_1_2_2(14'd16171),
.W_in_1_2_3(14'd368),
.W_in_1_2_4(14'd16228),
.W_in_1_3_0(14'd374),
.W_in_1_3_1(14'd114),
.W_in_1_3_2(14'd136),
.W_in_1_3_3(14'd149),
.W_in_1_3_4(14'd42),
.W_in_1_4_0(14'd18),
.W_in_1_4_1(14'd110),
.W_in_1_4_2(14'd16376),
.W_in_1_4_3(14'd11),
.W_in_1_4_4(14'd16006),
.W_in_2_0_0(14'd30),
.W_in_2_0_1(14'd59),
.W_in_2_0_2(14'd103),
.W_in_2_0_3(14'd15965),
.W_in_2_0_4(14'd16332),
.W_in_2_1_0(14'd16024),
.W_in_2_1_1(14'd330),
.W_in_2_1_2(14'd16272),
.W_in_2_1_3(14'd16171),
.W_in_2_1_4(14'd201),
.W_in_2_2_0(14'd70),
.W_in_2_2_1(14'd16364),
.W_in_2_2_2(14'd16135),
.W_in_2_2_3(14'd232),
.W_in_2_2_4(14'd16334),
.W_in_2_3_0(14'd162),
.W_in_2_3_1(14'd16123),
.W_in_2_3_2(14'd16136),
.W_in_2_3_3(14'd127),
.W_in_2_3_4(14'd135),
.W_in_2_4_0(14'd60),
.W_in_2_4_1(14'd16147),
.W_in_2_4_2(14'd15904),
.W_in_2_4_3(14'd16089),
.W_in_2_4_4(14'd16038),
.W_hn_0_0_0(14'd15928),
.W_hn_0_0_1(14'd129),
.W_hn_0_0_2(14'd16282),
.W_hn_0_0_3(14'd327),
.W_hn_0_0_4(14'd138),
.W_hn_0_1_0(14'd502),
.W_hn_0_1_1(14'd15766),
.W_hn_0_1_2(14'd43),
.W_hn_0_1_3(14'd358),
.W_hn_0_1_4(14'd44),
.W_hn_0_2_0(14'd16022),
.W_hn_0_2_1(14'd16149),
.W_hn_0_2_2(14'd82),
.W_hn_0_2_3(14'd16323),
.W_hn_0_2_4(14'd227),
.W_hn_0_3_0(14'd16158),
.W_hn_0_3_1(14'd16261),
.W_hn_0_3_2(14'd16129),
.W_hn_0_3_3(14'd15931),
.W_hn_0_3_4(14'd16219),
.W_hn_0_4_0(14'd16307),
.W_hn_0_4_1(14'd16065),
.W_hn_0_4_2(14'd16064),
.W_hn_0_4_3(14'd16140),
.W_hn_0_4_4(14'd16285),
.W_hn_1_0_0(14'd16338),
.W_hn_1_0_1(14'd16353),
.W_hn_1_0_2(14'd15801),
.W_hn_1_0_3(14'd16337),
.W_hn_1_0_4(14'd16002),
.W_hn_1_1_0(14'd276),
.W_hn_1_1_1(14'd15988),
.W_hn_1_1_2(14'd184),
.W_hn_1_1_3(14'd164),
.W_hn_1_1_4(14'd16073),
.W_hn_1_2_0(14'd333),
.W_hn_1_2_1(14'd16325),
.W_hn_1_2_2(14'd16002),
.W_hn_1_2_3(14'd218),
.W_hn_1_2_4(14'd16111),
.W_hn_1_3_0(14'd116),
.W_hn_1_3_1(14'd425),
.W_hn_1_3_2(14'd16368),
.W_hn_1_3_3(14'd16098),
.W_hn_1_3_4(14'd59),
.W_hn_1_4_0(14'd16330),
.W_hn_1_4_1(14'd310),
.W_hn_1_4_2(14'd567),
.W_hn_1_4_3(14'd279),
.W_hn_1_4_4(14'd16188),
.W_hn_2_0_0(14'd16246),
.W_hn_2_0_1(14'd400),
.W_hn_2_0_2(14'd1045),
.W_hn_2_0_3(14'd15944),
.W_hn_2_0_4(14'd15798),
.W_hn_2_1_0(14'd15952),
.W_hn_2_1_1(14'd322),
.W_hn_2_1_2(14'd6),
.W_hn_2_1_3(14'd143),
.W_hn_2_1_4(14'd725),
.W_hn_2_2_0(14'd15983),
.W_hn_2_2_1(14'd592),
.W_hn_2_2_2(14'd621),
.W_hn_2_2_3(14'd16232),
.W_hn_2_2_4(14'd500),
.W_hn_2_3_0(14'd160),
.W_hn_2_3_1(14'd230),
.W_hn_2_3_2(14'd16296),
.W_hn_2_3_3(14'd16217),
.W_hn_2_3_4(14'd16327),
.W_hn_2_4_0(14'd15507),
.W_hn_2_4_1(14'd16310),
.W_hn_2_4_2(14'd15484),
.W_hn_2_4_3(14'd15983),
.W_hn_2_4_4(14'd16056),
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
if(dut.fifo_shared_9_push) begin

finished_push=finished_push+1;end
if(dut.ap_done)begin $display("DONE %d",cycle);finished=finished+1;end
if(finished==120)begin if(writes!=15360 || finished_push!=120 || reads!=15360)$fatal;$finish;end
if(cycle>40000)$fatal;
end

endmodule
