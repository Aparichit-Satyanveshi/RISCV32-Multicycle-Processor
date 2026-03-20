`timescale 1ns/1ps

module riscv_tb_large;

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
        clk = 0;
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
        mem_rbusy = 0;
        mem_wbusy = 0;
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
            reset = 0;
            @(posedge clk);
            @(posedge clk);
            reset = 1;
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
            $display("Test 1: Basic Arithmetic Operations");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00500093;
            memory[1] = 32'h00300113;
            memory[2] = 32'h002081B3;
            memory[3] = 32'h40208233;
            memory[4] = 32'h00302023;
            memory[5] = 32'h00402223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 200);

            check_result(32'h00000000, 32'h00000008, "ADD result (5+3=8)");
            check_result(32'h00000004, 32'h00000002, "SUB result (5-3=2)");
        end
    endtask

    task test_logical_operations;
        begin
            test_num = 2;
            $display("\n========================================");
            $display("Test 2: Logical Operations");
            $display("========================================");

            init_memory();

            memory[0] = 32'h0F000093;
            memory[1] = 32'h0FF00113;
            memory[2] = 32'h0020F1B3;
            memory[3] = 32'h0020E233;
            memory[4] = 32'h0020C2B3;
            memory[5] = 32'h00302023;
            memory[6] = 32'h00402223;
            memory[7] = 32'h00502423;
            memory[8] = 32'h0200006F;

            reset_processor();
            wait_for_pc(32'd32, 200);

            check_result(32'h00000000, 32'h000000F0, "AND result");
            check_result(32'h00000004, 32'h000000FF, "OR result");
            check_result(32'h00000008, 32'h0000000F, "XOR result");
        end
    endtask

    task test_load_store;
        begin
            test_num = 3;
            $display("\n========================================");
            $display("Test 3: Load and Store Operations");
            $display("========================================");

            init_memory();

            memory[256] = 32'hDEADBEEF;
            memory[257] = 32'hCAFEBABE;

            memory[0] = 32'h40000093;
            memory[1] = 32'h0000A103;
            memory[2] = 32'h0040A183;
            memory[3] = 32'h003101B3;
            memory[4] = 32'h00302023;
            memory[5] = 32'h00202223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 200);

            check_result(32'h00000000, 32'hA9AC79AD, "ADD after loads");
            check_result(32'h00000004, 32'hDEADBEEF, "Loaded value stored");
        end
    endtask

    task test_branches;
        begin
            test_num = 4;
            $display("\n========================================");
            $display("Test 4: Branch Instructions");
            $display("========================================");

            init_memory();

            memory[0]  = 32'h00500093;
            memory[1]  = 32'h00500113;
            memory[2]  = 32'h00300193;
            memory[3]  = 32'h00208463;
            memory[4]  = 32'h06300213;
            memory[5]  = 32'h06300213;
            memory[6]  = 32'h02A00213;
            memory[7]  = 32'h00209463;
            memory[8]  = 32'h06300293;
            memory[9]  = 32'h06300293;
            memory[10] = 32'h03700293;
            memory[11] = 32'h0030C463;
            memory[12] = 32'h01E00313;
            memory[13] = 32'h00402023;
            memory[14] = 32'h00502223;
            memory[15] = 32'h00602423;
            memory[16] = 32'h0400006F;

            reset_processor();
            wait_for_pc(32'd64, 300);

            check_result(32'h00000000, 32'h0000002A, "BEQ branch taken (42)");
            check_result(32'h00000004, 32'h00000037, "BNE branch taken (55)");
            check_result(32'h00000008, 32'h0000001E, "BLT not taken (30)");
        end
    endtask

    task test_jumps;
        begin
            test_num = 5;
            $display("\n========================================");
            $display("Test 5: Jump Instructions");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00C000EF;
            memory[1] = 32'h00000013;
            memory[2] = 32'h00000013;
            memory[3] = 32'h00A00093;
            memory[4] = 32'h01400113;
            memory[5] = 32'h00208133;
            memory[6] = 32'h00202023;
            memory[7] = 32'h0200006F;

            reset_processor();
            wait_for_pc(32'd32, 200);

            check_result(32'h00000000, 32'h0000001E, "JAL and arithmetic (30)");
        end
    endtask

    task test_upper_immediates;
        begin
            test_num = 6;
            $display("\n========================================");
            $display("Test 6: Upper Immediate Instructions");
            $display("========================================");

            init_memory();

            memory[0] = 32'h123450B7;
            memory[1] = 32'h67808093;
            memory[2] = 32'h00102023;
            memory[3] = 32'h00001097;
            memory[4] = 32'h01008093;
            memory[5] = 32'h00102223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 200);

            check_result(32'h00000000, 32'h12345678, "LUI plus ADDI");
            check_result(32'h00000004, 32'h0000101C, "AUIPC plus ADDI");
        end
    endtask

    task test_shifts;
        begin
            test_num = 7;
            $display("\n========================================");
            $display("Test 7: Shift Operations");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00800093;
            memory[1] = 32'h00200113;
            memory[2] = 32'h002091B3;
            memory[3] = 32'h0020D233;
            memory[4] = 32'h00302023;
            memory[5] = 32'h00402223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 250);

            check_result(32'h00000000, 32'h00000020, "SLL result (32)");
            check_result(32'h00000004, 32'h00000002, "SRL result (2)");
        end
    endtask

    task test_loop;
        begin
            test_num = 8;
            $display("\n========================================");
            $display("Test 8: Loop Sum");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00000093;
            memory[1] = 32'h00100113;
            memory[2] = 32'h00600193;
            memory[3] = 32'h002080B3;
            memory[4] = 32'h00110113;
            memory[5] = 32'hFE314CE3;
            memory[6] = 32'h00102023;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 500);

            check_result(32'h00000000, 32'h0000000F, "Sum 1 to 5 = 15");
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

            memory[0] = 32'h40000093;
            memory[1] = 32'h0AB00113;
            memory[2] = 32'h00208023;
            memory[3] = 32'h12300113;
            memory[4] = 32'h00209123;
            memory[5] = 32'h0000A183;
            memory[6] = 32'h00302023;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 250);

            check_result(32'h00000000, 32'h012300AB, "SB/SH then LW");
        end
    endtask

    task test_set_less_than;
        begin
            test_num = 10;
            $display("\n========================================");
            $display("Test 10: Set Less Than");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00500093;
            memory[1] = 32'h00A00113;
            memory[2] = 32'h0020A1B3;
            memory[3] = 32'h00112233;
            memory[4] = 32'h00A0A293;
            memory[5] = 32'h00302023;
            memory[6] = 32'h00402223;
            memory[7] = 32'h00502423;
            memory[8] = 32'h0200006F;

            reset_processor();
            wait_for_pc(32'd32, 200);

            check_result(32'h00000000, 32'h00000001, "SLT (5<10=1)");
            check_result(32'h00000004, 32'h00000000, "SLT (10<5=0)");
            check_result(32'h00000008, 32'h00000001, "SLTI (5<10=1)");
        end
    endtask

    task test_jalr_return_address;
        begin
            test_num = 11;
            $display("\n========================================");
            $display("Test 11: JALR Return Address");
            $display("========================================");

            init_memory();

            memory[0] = 32'h01000093;
            memory[1] = 32'h000082E7;
            memory[2] = 32'h06300113;
            memory[3] = 32'h06300113;
            memory[4] = 32'h02A00113;
            memory[5] = 32'h00502023;
            memory[6] = 32'h00202223;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 250);

            check_result(32'h00000000, 32'h00000008, "JALR link register");
            check_result(32'h00000004, 32'h0000002A, "JALR branch target");
        end
    endtask

    task test_signed_unsigned_loads;
        begin
            test_num = 12;
            $display("\n========================================");
            $display("Test 12: Signed and Unsigned Loads");
            $display("========================================");

            init_memory();
            memory[256] = 32'h80F17EAA;

            memory[0] = 32'h40000093;
            memory[1] = 32'h00008103;
            memory[2] = 32'h00209183;
            memory[3] = 32'h0010C203;
            memory[4] = 32'h0020D283;
            memory[5] = 32'h00202023;
            memory[6] = 32'h00302223;
            memory[7] = 32'h00402423;
            memory[8] = 32'h00502623;
            memory[9] = 32'h0240006F;

            reset_processor();
            wait_for_pc(32'd36, 300);

            check_result(32'h00000000, 32'hFFFFFFAA, "LB sign-extends");
            check_result(32'h00000004, 32'hFFFF80F1, "LH sign-extends");
            check_result(32'h00000008, 32'h0000007E, "LBU zero-extends");
            check_result(32'h0000000C, 32'h000080F1, "LHU zero-extends");
        end
    endtask

    task test_sltu_sltiu;
        begin
            test_num = 13;
            $display("\n========================================");
            $display("Test 13: Unsigned Comparison");
            $display("========================================");

            init_memory();

            memory[0] = 32'hFFFFF0B7;
            memory[1] = 32'h00100113;
            memory[2] = 32'h0020B1B3;
            memory[3] = 32'h00213213;
            memory[4] = 32'h00302023;
            memory[5] = 32'h00402223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 250);

            check_result(32'h00000000, 32'h00000000, "SLTU unsigned compare");
            check_result(32'h00000004, 32'h00000001, "SLTIU immediate compare");
        end
    endtask

    task test_store_masking;
        begin
            test_num = 14;
            $display("\n========================================");
            $display("Test 14: Store Byte and Halfword Masking");
            $display("========================================");

            init_memory();
            memory[256] = 32'h11223344;

            memory[0] = 32'h40000093;
            memory[1] = 32'h05A00113;
            memory[2] = 32'h12300193;
            memory[3] = 32'h002080A3;
            memory[4] = 32'h00309123;
            memory[5] = 32'h0000A203;
            memory[6] = 32'h00402023;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 250);

            check_result(32'h00000000, 32'h01235A44, "Byte and halfword masks");
        end
    endtask

    task test_arithmetic_right_shift;
        begin
            test_num = 15;
            $display("\n========================================");
            $display("Test 15: Arithmetic Right Shift");
            $display("========================================");

            init_memory();

            memory[0] = 32'hFFF00093;
            memory[1] = 32'h4030D113;
            memory[2] = 32'h4010D193;
            memory[3] = 32'h00202023;
            memory[4] = 32'h00302223;
            memory[5] = 32'h0140006F;

            reset_processor();
            wait_for_pc(32'd20, 200);

            check_result(32'h00000000, 32'hFFFFFFFF, "SRAI by 3 keeps sign");
            check_result(32'h00000004, 32'hFFFFFFFF, "SRAI by 1 keeps sign");
        end
    endtask

task test_x0_immutability;
        begin
            test_num = 1;
            $display("\n========================================");
            $display("Test 1: x0 Immutability");
            $display("========================================");

            init_memory();

            memory[0] = 32'h07B00013;
            memory[1] = 32'h00500093;
            memory[2] = 32'h00002023;
            memory[3] = 32'h00102223;
            memory[4] = 32'h0100006F;

            reset_processor();
            wait_for_pc(32'd16, 200);

            check_result(32'h00000000, 32'h00000000, "Writes to x0 are ignored");
            check_result(32'h00000004, 32'h00000005, "x1 still writes correctly");
        end
    endtask

    task test_signed_vs_unsigned_compare;
        begin
            test_num = 2;
            $display("\n========================================");
            $display("Test 2: Signed vs Unsigned Compare");
            $display("========================================");

            init_memory();

            memory[0] = 32'hFFC00093;
            memory[1] = 32'h00300113;
            memory[2] = 32'h0020A1B3;
            memory[3] = 32'h0020B233;
            memory[4] = 32'h00302023;
            memory[5] = 32'h00402223;
            memory[6] = 32'h0180006F;

            reset_processor();
            wait_for_pc(32'd24, 200);

            check_result(32'h00000000, 32'h00000001, "SLT sees -4 < 3");
            check_result(32'h00000004, 32'h00000000, "SLTU sees 0xFFFFFFFC > 3");
        end
    endtask

    task test_mixed_branches;
        begin
            test_num = 3;
            $display("\n========================================");
            $display("Test 3: Mixed Branch Decisions");
            $display("========================================");

            init_memory();

            memory[0]  = 32'h00100093;
            memory[1]  = 32'h00200113;
            memory[2]  = 32'h00300193;
            memory[3]  = 32'h00110463;
            memory[4]  = 32'h00111463;
            memory[5]  = 32'h06300213;
            memory[6]  = 32'h04D00213;
            memory[7]  = 32'h00116463;
            memory[8]  = 32'h03700293;
            memory[9]  = 32'h02C00293;
            memory[10] = 32'h00315663;
            memory[11] = 32'h04200313;
            memory[12] = 32'h0080006F;
            memory[13] = 32'h02100313;
            memory[14] = 32'h00402023;
            memory[15] = 32'h00502223;
            memory[16] = 32'h00602423;
            memory[17] = 32'h0440006F;

            reset_processor();
            wait_for_pc(32'd68, 350);

            check_result(32'h00000000, 32'h0000004D, "BNE taken after BEQ not taken");
            check_result(32'h00000004, 32'h0000002C, "BLTU taken");
            check_result(32'h00000008, 32'h00000042, "BGE not taken");
        end
    endtask

    task test_jalr_subroutine;
        begin
            test_num = 4;
            $display("\n========================================");
            $display("Test 4: JALR Subroutine Jump");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00000097;
            memory[1] = 32'h00C08093;
            memory[2] = 32'h000082E7;
            memory[3] = 32'h00000013;
            memory[4] = 32'h02A00113;
            memory[5] = 32'h00800193;
            memory[6] = 32'h00502023;
            memory[7] = 32'h00202223;
            memory[8] = 32'h00302423;
            memory[9] = 32'h0240006F;

            reset_processor();
            wait_for_pc(32'd36, 250);

            check_result(32'h00000000, 32'h0000000C, "JALR link register holds return PC");
            check_result(32'h00000004, 32'h0000002A, "Subroutine body executed");
            check_result(32'h00000008, 32'h00000008, "Code after target still runs");
        end
    endtask

    task test_offset_loads;
        begin
            test_num = 5;
            $display("\n========================================");
            $display("Test 5: Offset Loads");
            $display("========================================");

            init_memory();
            memory[256] = 32'h80F17EAA;

            memory[0] = 32'h40000093;
            memory[1] = 32'h00308103;
            memory[2] = 32'h0020C183;
            memory[3] = 32'h00009203;
            memory[4] = 32'h0020D283;
            memory[5] = 32'h00202023;
            memory[6] = 32'h00302223;
            memory[7] = 32'h00402423;
            memory[8] = 32'h00502623;
            memory[9] = 32'h0280006F;

            reset_processor();
            wait_for_pc(32'd40, 300);

            check_result(32'h00000000, 32'hFFFFFF80, "LB from byte 3");
            check_result(32'h00000004, 32'h000000F1, "LBU from byte 2");
            check_result(32'h00000008, 32'h00007EAA, "LH from byte 0");
            check_result(32'h0000000C, 32'h000080F1, "LHU from byte 2");
        end
    endtask

    task test_store_overlay;
        begin
            test_num = 6;
            $display("\n========================================");
            $display("Test 6: Store Overlay Masking");
            $display("========================================");

            init_memory();
            memory[256] = 32'h11223344;

            memory[0] = 32'h40000193;
            memory[1] = 32'h0AA00093;
            memory[2] = 32'h05500113;
            memory[3] = 32'h001180A3;
            memory[4] = 32'h00219123;
            memory[5] = 32'h0001A203;
            memory[6] = 32'h00402023;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 250);

            check_result(32'h00000000, 32'h0055AA44, "SB and SH update only selected bytes");
        end
    endtask

    task test_shift_corner_cases;
        begin
            test_num = 7;
            $display("\n========================================");
            $display("Test 7: Shift Corner Cases");
            $display("========================================");

            init_memory();

            memory[0] = 32'h800000B7;
            memory[1] = 32'h4010D113;
            memory[2] = 32'h0040D193;
            memory[3] = 32'h00309213;
            memory[4] = 32'h00202023;
            memory[5] = 32'h00302223;
            memory[6] = 32'h00402423;
            memory[7] = 32'h0200006F;

            reset_processor();
            wait_for_pc(32'd32, 250);

            check_result(32'h00000000, 32'hC0000000, "SRAI keeps sign bit");
            check_result(32'h00000004, 32'h08000000, "SRLI inserts zeros");
            check_result(32'h00000008, 32'h00000000, "SLLI overflow wraps out");
        end
    endtask

    task test_branch_loop_stability;
        begin
            test_num = 8;
            $display("\n========================================");
            $display("Test 8: Loop Stability");
            $display("========================================");

            init_memory();

            memory[0] = 32'h00100093;
            memory[1] = 32'h00000113;
            memory[2] = 32'h00600193;
            memory[3] = 32'h00110133;
            memory[4] = 32'h00108093;
            memory[5] = 32'hFE30CCE3;
            memory[6] = 32'h00202023;
            memory[7] = 32'h01C0006F;

            reset_processor();
            wait_for_pc(32'd28, 500);

            check_result(32'h00000000, 32'h0000000F, "Loop accumulates 1+2+3+4+5");
        end
    endtask
    initial begin
        $display("========================================");
        $display("Combined RISC-V Processor Testbench");
        $display("========================================");

        passed_tests = 0;
        total_tests = 0;
        test_num = 0;

        // riscv_testbench_1 + riscv_testbench_more coverage
        test_basic_arithmetic();
        test_logical_operations();
        test_load_store();
        test_branches();
        test_jumps();
        test_upper_immediates();
        test_shifts();
        test_loop();
        test_byte_halfword_access();
        test_set_less_than();
        test_jalr_return_address();
        test_signed_unsigned_loads();
        test_sltu_sltiu();
        test_store_masking();
        test_arithmetic_right_shift();

        // riscv_testbench_tough coverage
        test_x0_immutability();
        test_signed_vs_unsigned_compare();
        test_mixed_branches();
        test_jalr_subroutine();
        test_offset_loads();
        test_store_overlay();
        test_shift_corner_cases();
        test_branch_loop_stability();

        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Passed: %0d/%0d tests", passed_tests, total_tests);
        $display("Score: %0d%%", (passed_tests * 100) / total_tests);
        $display("========================================\n");

        if (passed_tests == total_tests) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end

        $finish;
    end

    initial begin
        #1500000;
        $display("\n[ERROR] Simulation timeout - processor may be stuck");
        $display("Passed: %0d/%0d tests before timeout", passed_tests, total_tests);
        $finish;
    end
endmodule
