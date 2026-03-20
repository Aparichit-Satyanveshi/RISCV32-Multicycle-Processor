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


// Main Decoder Module that generates high-level control signals from opcode.
module main_decoder(opcode, reg_write, imm_src, alu_src, mem_write, res_src, branch, jump, ALU_Op);
input [6:0] opcode;
output reg reg_write ;
output reg [2:0] imm_src; // selects immediate format like I-S-B-J-U
output reg alu_src;     // 1 -> use imm and 0-> use register
output reg mem_write;  //Enabler for memory write operation
output reg[1:0] res_src; // selects where to put result (ALU/Memory/PC+4)
output reg branch ;    // brnach control
output reg jump;      // jump control
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

 //Program Counter Module used to store pc, pc+4, and
 // selects next_pc based upon control signals(branch,jump,etc.)
module next_pc_selected(pc_upgraded, pc_target,jalr_target,
                        branch,jump,jalr,branch_taken,next_pc);
input [31:0] pc_upgraded;// PC+ 4
input [31:0] pc_target ;// Branch/ jal target
input [31:0] jalr_target ;// Register based jump target
input branch,jump,jalr,branch_taken;
output [31:0] next_pc;

//Priority = jalr > jal or taken branch > pc+4
assign next_pc = jalr ? {jalr_target[31:1],1'b0}:
                 (jump | (branch && branch_taken)) ? pc_target :
                 pc_upgraded;
endmodule

// Register File
// 32 × 32-bit registers with 2 read ports and 1 write port
// x0 is always hardwired to 0 , by convention.
module reg_file(clk,we3,a1,a2,a3,wd3,rd1,rd2);
input clk,we3; 
input [4:0] a1,a2,a3;
input [31:0] wd3 ;
output [31:0]rd1,rd2;

reg [31:0] reg_f[0:31];
//Write operation
always @(posedge clk) begin
    if(we3 && a3 !=0) reg_f[a3]<=wd3;// preventing any change in x0
end
//Read operation
assign rd1 = (a1==0) ? 32'b0 : reg_f[a1];
assign rd2 = (a2==0) ? 32'b0 : reg_f[a2];
endmodule

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
  3'b011 : imm = {{11{inst[31]}},inst[31],inst[19:12],inst[20],inst[30:21],1'b0};//J-type
  3'b100 : imm = {inst[31:12],12'b0}; //U-type
  default : imm = 32'b0;
  endcase
end
endmodule


module riscv_processor #(
    parameter RESET_ADDR = 32'h00000000,
    parameter ADDR_WIDTH = 32
)(
    input clk,
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0] mem_wmask,
    input [31:0] mem_rdata,
    output mem_rstrb,
    input mem_rbusy,
    input mem_wbusy,
    input reset
);

// For PC
wire [31:0] pc_upgraded, pc_target, pc_next;
wire [31:0] jalr_target;
// For incoming instructions
wire [31:0] instruction;
wire [6:0] opcode;
wire [4:0] rs1, rs2, rd;
wire [2:0] funct3;
wire funct7_bit5;
// For control signals
wire reg_write, alu_src, mem_write, branch, jump, jalr;
wire [2:0] imm_src;
wire [1:0] res_src, ALU_Op;
wire [3:0] Alu_control;
// For data wires
wire [31:0] imm, rs1_data, rs2_data, alu_a, alu_b, alu_result, load_data, result;
wire zero, branch_taken;
wire [7:0] load_byte;
wire [15:0] load_half;
wire [4:0] load_byte_shift;
wire [4:0] load_half_shift;
reg [31:0] pc;
reg [31:0] instr_reg;
reg [31:0] data_reg;
reg [31:0] alu_out_reg;
reg [31:0] pc_plus4_reg;
reg [2:0] state;
wire is_fetch_state, is_load_result;

localparam FETCH        = 3'd0;
localparam FETCH_WAIT   = 3'd1;
localparam EXECUTE      = 3'd2;
localparam MEMREAD      = 3'd3;
localparam MEMREAD_WAIT = 3'd4;
localparam WRITEBACK    = 3'd5;

// Fetching from memory
assign is_fetch_state = (state == FETCH) || (state == FETCH_WAIT);
assign is_load_result = (res_src == 2'b01);
assign instruction = instr_reg;
assign mem_addr = is_fetch_state ? pc :
                  (state == EXECUTE) ? alu_result : alu_out_reg;
assign mem_rstrb = (state == FETCH) || (state == MEMREAD);
// Separate out instruction bits
assign funct7_bit5 = instruction[30];
assign rs2 = instruction[24:20];
assign rs1 = instruction[19:15];
assign funct3 = instruction[14:12];
assign rd = instruction[11:7];
assign opcode = instruction[6:0];

// Initialise our PC-values
assign pc_upgraded = pc + 32'd4;
assign pc_target = pc + imm;
assign jalr_target = rs1_data + imm;
assign jalr = (opcode == 7'b1100111);
next_pc_selected my_next_pc(
    .pc_upgraded(pc_upgraded),.pc_target(pc_target),.jalr_target(jalr_target),
    .branch(branch),.jump(jump),.jalr(jalr),.branch_taken(branch_taken),.next_pc(pc_next));

// Initialise our decoder modules
main_decoder my_main_dec(.opcode(opcode),.reg_write(reg_write),.imm_src(imm_src),
    .alu_src(alu_src),.mem_write(mem_write),
    .res_src(res_src),.branch(branch),
    .jump(jump),.ALU_Op(ALU_Op));

alu_decoder my_alu_dec(.ALU_Op(ALU_Op),.funct3(funct3),.funct7_bit5(funct7_bit5),
    .opcode(opcode),.Alu_control(Alu_control));

imm_gen my_imm_gen(.inst(instruction),.imm_src(imm_src),.imm(imm));

// Register file
wire reg_write_final;
assign reg_write_final = (state == WRITEBACK) && reg_write;
reg_file my_reg_file(.clk(clk),.we3(reg_write_final),.a1(rs1),
    .a2(rs2),.a3(rd), .wd3(result),.rd1(rs1_data),.rd2(rs2_data));

// If opcode => auipc then use pc
assign alu_a = (opcode == 7'b0010111) ? pc : rs1_data;
// If alu_src == 1 => I, S, U, J type => need imm; otherwise use rs2_data
assign alu_b = alu_src ? imm : rs2_data;
// For ALU module
alu my_alu( .A(alu_a),.B(alu_b),.Alu_control(Alu_control),.res(alu_result),.zero(zero));

// Branch
assign branch_taken = (funct3 == 3'b000) ? zero : // beq
                      (funct3 == 3'b001) ? ~zero : // bne
                      (funct3 == 3'b100) ? alu_result[0] :  // blt
                      (funct3 == 3'b101) ? ~alu_result[0] : // bge
                      (funct3 == 3'b110) ? alu_result[0] :  // bltu
                      (funct3 == 3'b111) ? ~alu_result[0] : // bgeu
                      1'b0;

// Store
assign mem_wdata = (funct3 == 3'b000) ? {4{rs2_data[7:0]}} :
                   (funct3 == 3'b001) ? {2{rs2_data[15:0]}} :
                   rs2_data;

assign mem_wmask = (state != EXECUTE || !mem_write) ? 4'b0000 :
                   (funct3 == 3'b000) ? (4'b0001 << alu_result[1:0]) :
                   (funct3 == 3'b001) ? (alu_result[1] ? 4'b1100 : 4'b0011) :
                   4'b1111;

// Load
assign load_byte_shift = {alu_out_reg[1:0], 3'b000};
assign load_half_shift = {alu_out_reg[1], 4'b0000};
assign load_byte = data_reg >> load_byte_shift;
assign load_half = data_reg >> load_half_shift;
assign load_data = (funct3 == 3'b000) ? {{24{load_byte[7]}}, load_byte} :
                   (funct3 == 3'b001) ? {{16{load_half[15]}}, load_half} :
                   (funct3 == 3'b010) ? data_reg :
                   (funct3 == 3'b100) ? {24'b0, load_byte} :
                   (funct3 == 3'b101) ? {16'b0, load_half} :
                   32'b0;

// Final results
assign result = (res_src == 2'b00) ? alu_out_reg :
                is_load_result ? load_data :
                (res_src == 2'b10) ? pc_plus4_reg :
                32'b0;

//FSM Block : FETCH -> FETCH_WAIT -> EXECUTE -> (MEMREAD -> MEMREAD_WAIT) -> WRITEBACK
always @(posedge clk) begin
    if (!reset) begin
        pc <= RESET_ADDR;
        instr_reg <= 32'b0;
        data_reg <= 32'b0;
        alu_out_reg <= 32'b0;
        pc_plus4_reg <= 32'b0;
        state <= FETCH; // active-low reset
    end else begin
        case (state)
            FETCH: begin
                state <= FETCH_WAIT;
            end

            FETCH_WAIT: begin
                instr_reg <= mem_rdata;
                state <= EXECUTE;
            end

            EXECUTE: begin
                alu_out_reg <= alu_result;
                pc_plus4_reg <= pc_upgraded;
                if (mem_write) begin
                    pc <= pc_next;
                    state <= FETCH;
                end else if (is_load_result) begin
                    state <= MEMREAD;
                end else begin
                    pc <= pc_next;
                    state <= WRITEBACK;
                end
            end

            MEMREAD: begin
                state <= MEMREAD_WAIT;
            end

            MEMREAD_WAIT: begin
                data_reg <= mem_rdata;
                pc <= pc_next;
                state <= WRITEBACK;
            end

            WRITEBACK: begin
                state <= FETCH;
            end

            default: begin
                pc <= RESET_ADDR;
                instr_reg <= 32'b0;
                data_reg <= 32'b0;
                alu_out_reg <= 32'b0;
                pc_plus4_reg <= 32'b0;
                state <= FETCH;
            end
        endcase
    end
end
endmodule
