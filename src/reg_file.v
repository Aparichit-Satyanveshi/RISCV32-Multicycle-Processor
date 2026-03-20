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


