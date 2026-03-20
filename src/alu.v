// ALU Module that performs operations based upon control signals
module alu(A,B,Alu_control,res,zero);
input [31:0] A,B;
input [3:0] Alu_control;
output reg [31:0] res;
output zero;

assign zero = (res==32'b0); // Zero flag used for Branch instructions
 
always @(*) begin
    case(Alu_control)
      4'b0000 : res = A + B ; // add,addi,lw,sw,auipc
      4'b0001 : res = A - B; // sub
      4'b0010 : res = A & B ;// and,andi
      4'b0011 : res = A | B; // or,ori
      4'b0100 : res = A ^ B;// xor,xori
      4'b0101 : res = A<<B[4:0]; // sll,slli
      4'b0110 : res = A>>B[4:0]; // srl,srli
      4'b0111 : res = $signed(A) >>> B[4:0]; //sra,srai
      4'b1000 : res = ($signed(A)< $signed(B)) ? 32'd1 : 32'd0 ; //slt,slti
      4'b1001 : res = (A<B) ? 32'd1 : 32'd0;//sltu,sltiu
      4'b1010 : res = B;// lui as it handled by imm_path
      default : res = 32'b0;
    endcase
end

endmodule

