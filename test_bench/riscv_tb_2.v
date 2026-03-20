`timescale 1ns/1ps

module riscv_testbench_24115126;

    reg clk;
    reg reset;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    reg         mem_rbusy;
    reg         mem_wbusy;

    reg [31:0] memory [0:4095];
    reg [31:0] read_data;

    integer test_num;
    integer passed_tests;
    integer total_tests;
    integer cycle_count;
    integer i;

    riscv_processor #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(32)
    ) uut (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset(reset)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (mem_rstrb) begin
            read_data <= memory[mem_addr[31:2]];
        end
    end

    assign mem_rdata = read_data;

    always @(posedge clk) begin
        if (mem_wmask != 4'b0000) begin
            if (mem_wmask[0]) memory[mem_addr[31:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) memory[mem_addr[31:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) memory[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) memory[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
        end
    end

    initial begin
        mem_rbusy = 1'b0;
        mem_wbusy = 1'b0;
    end

    always @(posedge clk) begin
        if (!reset)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    task init_memory;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                memory[i] = 32'h00000013;
            end
            read_data = 32'h00000013;
        end
    endtask

    task reset_processor;
        begin
            reset = 1'b0;
            @(posedge clk);
            @(posedge clk);
            reset = 1'b1;
            cycle_count = 0;
        end
    endtask

    task wait_for_pc;
        input [31:0] target_pc;
        input integer max_cycles;
        integer j;
        begin
            for (j = 0; j < max_cycles; j = j + 1) begin
                @(posedge clk);
                if (mem_addr == target_pc && mem_rstrb) begin
                    j = max_cycles;
                end
            end
        end
    endtask

    task check_result;
        input [31:0] addr;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            total_tests = total_tests + 1;
            if (memory[addr[31:2]] === expected) begin
                $display("[PASS] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
            end
        end
    endtask

    task test_basic_arithmetic;
        begin
            test_num = 1;
            $display("\n========================================");
            $display("Test 1: Basic Arithmetic");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00500093;  // addi x1, x0, 5
            memory[1] = 32'h00300113;  // addi x2, x0, 3
            memory[2] = 32'h002081B3;  // add  x3, x1, x2
            memory[3] = 32'h40208233;  // sub  x4, x1, x2
            memory[4] = 32'h00302023;  // sw   x3, 0(x0)
            memory[5] = 32'h00402223;  // sw   x4, 4(x0)
            memory[6] = 32'h0180006F;  // jal  x0, 24

            reset_processor();
            wait_for_pc(32'd24, 200);

            check_result(32'h00000000, 32'h00000008, "ADD result");
            check_result(32'h00000004, 32'h00000002, "SUB result");
        end
    endtask

    task test_logic_ops;
        begin
            test_num = 2;
            $display("\n========================================");
            $display("Test 2: Logical Operations");
            $display("========================================");

            init_memory();

            memory[0] = 32'h0F000093;  // addi x1, x0, 0xF0
            memory[1] = 32'h0FF00113;  // addi x2, x0, 0xFF
            memory[2] = 32'h0020F1B3;  // and  x3, x1, x2
            memory[3] = 32'h0020E233;  // or   x4, x1, x2
            memory[4] = 32'h0020C2B3;  // xor  x5, x1, x2
            memory[5] = 32'h00302023;  // sw   x3, 0(x0)
            memory[6] = 32'h00402223;  // sw   x4, 4(x0)
            memory[7] = 32'h00502423;  // sw   x5, 8(x0)
            memory[8] = 32'h0200006F;  // jal  x0, 32

            reset_processor();
            wait_for_pc(32'd32, 220);

            check_result(32'h00000000, 32'h000000F0, "AND result");
            check_result(32'h00000004, 32'h000000FF, "OR result");
            check_result(32'h00000008, 32'h0000000F, "XOR result");
        end
    endtask

    task test_load_store;
        begin
            test_num = 3;
            $display("\n========================================");
            $display("Test 3: Load and Store");
            $display("========================================");

            init_memory();
            memory[256] = 32'hDEADBEEF;
            memory[257] = 32'hCAFEBABE;

            memory[0] = 32'h40000093;  // addi x1, x0, 1024
            memory[1] = 32'h0000A103;  // lw   x2, 0(x1)
            memory[2] = 32'h0040A183;  // lw   x3, 4(x1)
            memory[3] = 32'h003101B3;  // add  x3, x2, x3
            memory[4] = 32'h00302023;  // sw   x3, 0(x0)
            memory[5] = 32'h00202223;  // sw   x2, 4(x0)
            memory[6] = 32'h0180006F;  // jal  x0, 24

            reset_processor();
            wait_for_pc(32'd24, 250);

            check_result(32'h00000000, 32'hA9AC79AD, "Load-add-store result");
            check_result(32'h00000004, 32'hDEADBEEF, "First loaded word");
        end
    endtask

    task test_branches;
        begin
            test_num = 4;
            $display("\n========================================");
            $display("Test 4: Branch Instructions");
            $display("========================================");

            init_memory();

            memory[0]  = 32'h00500093;  // addi x1, x0, 5
            memory[1]  = 32'h00500113;  // addi x2, x0, 5
            memory[2]  = 32'h00300193;  // addi x3, x0, 3
            memory[3]  = 32'h00208463;  // beq  x1, x2, +8
            memory[4]  = 32'h06300213;  // skipped
            memory[5]  = 32'h06300213;  // skipped
            memory[6]  = 32'h02A00213;  // addi x4, x0, 42
            memory[7]  = 32'h00209463;  // bne  x1, x3, +8
            memory[8]  = 32'h06300293;  // skipped
            memory[9]  = 32'h06300293;  // skipped
            memory[10] = 32'h03700293;  // addi x5, x0, 55
            memory[11] = 32'h0030C463;  // blt  x1, x3, +8 (not taken)
            memory[12] = 32'h01E00313;  // addi x6, x0, 30
            memory[13] = 32'h00402023;  // sw   x4, 0(x0)
            memory[14] = 32'h00502223;  // sw   x5, 4(x0)
            memory[15] = 32'h00602423;  // sw   x6, 8(x0)
            memory[16] = 32'h0400006F;  // jal  x0, 64

            reset_processor();
            wait_for_pc(32'd64, 350);

            check_result(32'h00000000, 32'h0000002A, "BEQ taken");
            check_result(32'h00000004, 32'h00000037, "BNE taken");
            check_result(32'h00000008, 32'h0000001E, "BLT not taken");
        end
    endtask

    task test_jumps;
        begin
            test_num = 5;
            $display("\n========================================");
            $display("Test 5: Jump Instructions");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00C000EF;  // jal  x1, 12
            memory[1] = 32'h00000013;  // nop
            memory[2] = 32'h00000013;  // nop
            memory[3] = 32'h00A00093;  // addi x1, x0, 10
            memory[4] = 32'h01400113;  // addi x2, x0, 20
            memory[5] = 32'h00208133;  // add  x2, x1, x2
            memory[6] = 32'h00202023;  // sw   x2, 0(x0)
            memory[7] = 32'h0200006F;  // jal  x0, 32

            reset_processor();
            wait_for_pc(32'd32, 250);

            check_result(32'h00000000, 32'h0000001E, "JAL execution path");
        end
    endtask

    task test_upper_immediates;
        begin
            test_num = 6;
            $display("\n========================================");
            $display("Test 6: LUI and AUIPC");
            $display("========================================");

            init_memory();

            memory[0] = 32'h123450B7;  // lui   x1, 0x12345
            memory[1] = 32'h67808093;  // addi  x1, x1, 0x678
            memory[2] = 32'h00102023;  // sw    x1, 0(x0)
            memory[3] = 32'h00001097;  // auipc x1, 0x1
            memory[4] = 32'h01008093;  // addi  x1, x1, 16
            memory[5] = 32'h00102223;  // sw    x1, 4(x0)
            memory[6] = 32'h0180006F;  // jal   x0, 24

            reset_processor();
            wait_for_pc(32'd24, 220);

            check_result(32'h00000000, 32'h12345678, "LUI + ADDI");
            check_result(32'h00000004, 32'h0000101C, "AUIPC + ADDI");
        end
    endtask

    task test_shifts;
        begin
            test_num = 7;
            $display("\n========================================");
            $display("Test 7: Shift Operations");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00800093;  // addi x1, x0, 8
            memory[1] = 32'h00200113;  // addi x2, x0, 2
            memory[2] = 32'h002091B3;  // sll  x3, x1, x2
            memory[3] = 32'h0020D233;  // srl  x4, x1, x2
            memory[4] = 32'h4030D293;  // srai x5, x1, 3
            memory[5] = 32'h00302023;  // sw   x3, 0(x0)
            memory[6] = 32'h00402223;  // sw   x4, 4(x0)
            memory[7] = 32'h00502423;  // sw   x5, 8(x0)
            memory[8] = 32'h0200006F;  // jal  x0, 32

            reset_processor();
            wait_for_pc(32'd32, 260);

            check_result(32'h00000000, 32'h00000020, "SLL result");
            check_result(32'h00000004, 32'h00000002, "SRL result");
            check_result(32'h00000008, 32'h00000001, "SRAI result");
        end
    endtask

    task test_loop_sum;
        begin
            test_num = 8;
            $display("\n========================================");
            $display("Test 8: Loop Sum");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00000093;  // addi x1, x0, 0
            memory[1] = 32'h00100113;  // addi x2, x0, 1
            memory[2] = 32'h00600193;  // addi x3, x0, 6
            memory[3] = 32'h002080B3;  // add  x1, x1, x2
            memory[4] = 32'h00110113;  // addi x2, x2, 1
            memory[5] = 32'hFE314CE3;  // blt  x2, x3, -8
            memory[6] = 32'h00102023;  // sw   x1, 0(x0)
            memory[7] = 32'h01C0006F;  // jal  x0, 28

            reset_processor();
            wait_for_pc(32'd28, 500);

            check_result(32'h00000000, 32'h0000000F, "Sum 1 to 5");
        end
    endtask

    task test_byte_halfword_access;
        begin
            test_num = 9;
            $display("\n========================================");
            $display("Test 9: Byte and Halfword Access");
            $display("========================================");

            init_memory();
            memory[256] = 32'h00000000;

            memory[0] = 32'h40000093;  // addi x1, x0, 1024
            memory[1] = 32'h0AB00113;  // addi x2, x0, 0xAB
            memory[2] = 32'h00208023;  // sb   x2, 0(x1)
            memory[3] = 32'h12300113;  // addi x2, x0, 0x123
            memory[4] = 32'h00209123;  // sh   x2, 2(x1)
            memory[5] = 32'h0000A183;  // lw   x3, 0(x1)
            memory[6] = 32'h00302023;  // sw   x3, 0(x0)
            memory[7] = 32'h01C0006F;  // jal  x0, 28

            reset_processor();
            wait_for_pc(32'd28, 260);

            check_result(32'h00000000, 32'h012300AB, "SB and SH masking");
        end
    endtask

    task test_signed_unsigned_loads;
        begin
            test_num = 10;
            $display("\n========================================");
            $display("Test 10: Signed and Unsigned Loads");
            $display("========================================");

            init_memory();
            memory[256] = 32'h80F17EAA;

            memory[0] = 32'h40000093;  // addi x1, x0, 1024
            memory[1] = 32'h00008103;  // lb   x2, 0(x1)
            memory[2] = 32'h00209183;  // lh   x3, 2(x1)
            memory[3] = 32'h0010C203;  // lbu  x4, 1(x1)
            memory[4] = 32'h0020D283;  // lhu  x5, 2(x1)
            memory[5] = 32'h00202023;  // sw   x2, 0(x0)
            memory[6] = 32'h00302223;  // sw   x3, 4(x0)
            memory[7] = 32'h00402423;  // sw   x4, 8(x0)
            memory[8] = 32'h00502623;  // sw   x5, 12(x0)
            memory[9] = 32'h0240006F;  // jal  x0, 36

            reset_processor();
            wait_for_pc(32'd36, 320);

            check_result(32'h00000000, 32'hFFFFFFAA, "LB sign extension");
            check_result(32'h00000004, 32'hFFFF80F1, "LH sign extension");
            check_result(32'h00000008, 32'h0000007E, "LBU zero extension");
            check_result(32'h0000000C, 32'h000080F1, "LHU zero extension");
        end
    endtask

    task test_x0_and_compare;
        begin
            test_num = 11;
            $display("\n========================================");
            $display("Test 11: x0 and Compare Instructions");
            $display("========================================");

            init_memory();

            memory[0] = 32'h07B00013;  // addi x0, x0, 123
            memory[1] = 32'hFFC00093;  // addi x1, x0, -4
            memory[2] = 32'h00300113;  // addi x2, x0, 3
            memory[3] = 32'h0020A1B3;  // slt  x3, x1, x2
            memory[4] = 32'h0020B233;  // sltu x4, x1, x2
            memory[5] = 32'h00002023;  // sw   x0, 0(x0)
            memory[6] = 32'h00302223;  // sw   x3, 4(x0)
            memory[7] = 32'h00402423;  // sw   x4, 8(x0)
            memory[8] = 32'h0200006F;  // jal  x0, 32

            reset_processor();
            wait_for_pc(32'd32, 260);

            check_result(32'h00000000, 32'h00000000, "x0 remains zero");
            check_result(32'h00000004, 32'h00000001, "SLT signed compare");
            check_result(32'h00000008, 32'h00000000, "SLTU unsigned compare");
        end
    endtask

    initial begin
        $display("========================================");
        $display("RISC-V Testbench for 24115126_riscv.v");
        $display("Reference style: riscv_tb_large.v");
        $display("========================================");

        passed_tests = 0;
        total_tests = 0;
        test_num = 0;

        test_basic_arithmetic();
        test_logic_ops();
        test_load_store();
        test_branches();
        test_jumps();
        test_upper_immediates();
        test_shifts();
        test_loop_sum();
        test_byte_halfword_access();
        test_signed_unsigned_loads();
        test_x0_and_compare();

        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Passed: %0d/%0d tests", passed_tests, total_tests);
        $display("Score: %0d%%", (passed_tests * 100) / total_tests);
        $display("========================================");

        if (passed_tests == total_tests)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** SOME TESTS FAILED ***");

        $finish;
    end

    initial begin
        #1500000;
        $display("\n[ERROR] Simulation timeout");
        $display("Passed: %0d/%0d tests before timeout", passed_tests, total_tests);
        $finish;
    end

endmodule
