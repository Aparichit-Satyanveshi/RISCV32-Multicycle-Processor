 //Program Counter Module used to store pc, pc+4, and
 // selects next_pc based upon control signals(branch,jump,etc.)
module pc_adder(pc,pc_upgraded);
 input [31:0] pc;
 output [31:0] pc_upgraded;
 assign pc_upgraded = pc + 32'd4;
endmodule

module next_pc_selected(pc_upgraded, pc_target,jalr_target,
                        branch,jump,jalr,branch_taken,next_pc);
input [31:0] pc_upgraded;// PC+4
input [31:0] pc_target ;// Branch/JAL target
input [31:0] jalr_target ;// Register based jump target
input branch,jump,jalr,branch_taken;
output [31:0] next_pc;

//Priority = jalr > jal or taken branch > pc+4
assign next_pc = jalr ? {jalr_target[31:1],1'b0}: // jalr
                 (jump | (branch && branch_taken)) ? pc_target : //jal
                 pc_upgraded;//default upgrade
endmodule
