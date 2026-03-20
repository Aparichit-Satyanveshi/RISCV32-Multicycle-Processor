 //ALU Decoder Module that generates ALU control signals 
 // based on ALU_Op and instruction fields(funct3, funct7, opcode) of given encoding
module alu_decoder(ALU_Op,funct3,funct7_bit5,opcode,Alu_control);
input [1:0] ALU_Op ;
input [2:0] funct3;
input funct7_bit5;
input [6:0] opcode;
output reg [3:0] Alu_control;

always @(*) begin
   case(ALU_Op)
     2'b00 : Alu_control = 4'b0000;// for load - store -> add

     // B types
     2'b01 : begin
        case(funct3)
         3'b000, 3'b001 : Alu_control = 4'b0001;// beq,bne -> sub
         3'b100, 3'b101 : Alu_control = 4'b1000;//blt,bge -> slt
         3'b110, 3'b111 : Alu_control = 4'b1001;//bltu,bgeu -> sltu
         default : Alu_control = 4'b0001;
        endcase
     end

     // for I & R types
     2'b10 : begin
        case(funct3)
         3'b000 : Alu_control = (opcode == 7'b0110011 && funct7_bit5) ? 4'b0001 : 4'b0000;// add or sub
         3'b001 : Alu_control = 4'b0101 ; //sll
         3'b010 : Alu_control = 4'b1000; // slt
         3'b011 : Alu_control = 4'b1001; // sltu
         3'b100 : Alu_control = 4'b0100; // xor
         3'b101 : Alu_control = funct7_bit5 ? 4'b0111 : 4'b0110 ; // sra or srl
         3'b110 : Alu_control = 4'b0011; // or
         3'b111 : Alu_control = 4'b0010; // and
         default : Alu_control = 4'b0000;
        endcase
     end

     //LUI
     2'b11 : Alu_control = 4'b1010;
     default : Alu_control = 4'b0000;
   endcase
end
endmodule
