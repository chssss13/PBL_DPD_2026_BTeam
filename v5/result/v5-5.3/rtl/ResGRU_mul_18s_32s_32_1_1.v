// 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689

`timescale 1 ns / 1 ps

 module ResGRU_mul_18s_32s_32_1_1(din0, din1, dout);
parameter ID = 1;
parameter NUM_STAGE = 0;
parameter din0_WIDTH = 14;
parameter din1_WIDTH = 12;
parameter dout_WIDTH = 26;

input [din0_WIDTH - 1 : 0] din0; 
input [din1_WIDTH - 1 : 0] din1; 
output [dout_WIDTH - 1 : 0] dout;

(* use_dsp = "no" *) wire signed [dout_WIDTH - 1 : 0] tmp_product;



























// Fixed Q4.10 coefficient 1039/1024. Keep the raw product and its width.
wire signed [dout_WIDTH - 1 : 0] operand = $signed(din0);
wire signed [dout_WIDTH - 1 : 0] times_fifteen = (operand <<< 4) - operand;
assign tmp_product = (operand <<< 10) + times_fifteen;








assign dout = tmp_product;





















endmodule
