// Main Decoder Module that generates high-level control signals from opcode.
module main_decoder(opcode, reg_write, imm_src, alu_src, mem_write, res_src, branch, jump, ALU_Op);
input [6:0] opcode;
output reg reg_write ;
output reg [2:0] imm_src;// selects immediate format like I-S-B-J-U
output reg alu_src;// 1 -> use imm and 0-> use register
output reg mem_write;//Enabler for memory write operation
output reg[1:0] res_src;// selects where to put result (ALU/Memory/PC+4)
output reg branch ;// brnach control
output reg jump;// jump control
output reg [1:0] ALU_Op;//for ALU decoder's input

always @(*) begin
   {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b0;
   case(opcode)
     7'b0110011 :{reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_000_0_0_00_0_0_10;// R-type
     7'b0010011 : {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_000_1_0_00_0_0_10;//I-type ALU
     7'b0000011 :  {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_000_1_0_01_0_0_00;// LOAD
     7'b0100011 : {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b0_001_1_1_00_0_0_00;// Store
     7'b1100011 :   {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b0_010_0_0_00_1_0_01;//Branch
     7'b1101111 :  {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_011_1_0_10_0_1_00;// JAL
     7'b1100111 :   {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_000_1_0_10_0_1_00;//JALR
     7'b0110111 : {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_100_1_0_00_0_0_11;//LUI
     7'b0010111 : {reg_write,imm_src,alu_src,mem_write,res_src,branch,jump,ALU_Op} = 13'b1_100_1_0_00_0_0_00;//AUIPC
   endcase
end
endmodule



