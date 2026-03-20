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
// Sign extension used
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
//FSM block
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
