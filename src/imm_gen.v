//Immediate Generator Module that extracts and 
//sign-extends immediate values from given encodings
module imm_gen(inst,imm_src,imm);
input [31:0] inst;
input [2:0] imm_src;
output reg [31:0] imm;

always @(*) begin
  case(imm_src)
  3'b000 : imm = {{20{inst[31]}},inst[31:20]} ; //I-type
  3'b001 : imm  = {{20{inst[31]}},inst[31:25],inst[11:7]};//S-type
  3'b010 : imm = {{19{inst[31]}},inst[31],inst[7],inst[30:25],inst[11:8],1'b0};//B-type
  // added LSB as it is always = 0
  3'b011 : imm = {{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};//J-type
  3'b100 : imm = {inst[31:12],12'b0}; //U-type
  default : imm = 32'b0;
  endcase
end
endmodule
