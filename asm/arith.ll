; ModuleID = 'riscv_jit'
source_filename = "riscv_jit"

declare i32 @jit_ecall(ptr, ptr, i64)

declare i32 @jit_jalr_interp(ptr, ptr, i64, i64)

define i32 @jit_main(ptr %0, i64 %1, i64 %2) {
alloca:
  %regs = alloca [32 x i64], align 8
  call void @llvm.memset.p0.i64(ptr align 8 %regs, i8 0, i64 256, i1 false)
  %sp_ptr = getelementptr i64, ptr %regs, i64 2
  store i64 %2, ptr %sp_ptr, align 4
  br label %bb_0x100b8

bb_0x100b8:                                       ; preds = %ecall_cont, %alloca
  br label %bb_0x100b0

bb_0x100b0:                                       ; preds = %bb_0x1025c, %bb_0x10254, %bb_0x1024c, %bb_0x10244, %bb_0x1023c, %bb_0x10234, %bb_0x1022c, %bb_0x10224, %bb_0x1021c, %bb_0x10214, %bb_0x1020c, %bb_0x10204, %mem_ok438, %bb_0x100b8
  %reg_ptr = getelementptr i64, ptr %regs, i64 0
  %rv = load i64, ptr %reg_ptr, align 4
  %addi = add i64 %rv, 93
  %reg_ptr1 = getelementptr i64, ptr %regs, i64 17
  store i64 %addi, ptr %reg_ptr1, align 4
  %ecall_ret = call i32 @jit_ecall(ptr %regs, ptr %0, i64 %1)
  %is_exit = icmp sge i32 %ecall_ret, 0
  br i1 %is_exit, label %ecall_exit, label %ecall_cont

bb_0x100e4:                                       ; No predecessors!
  %reg_ptr2 = getelementptr i64, ptr %regs, i64 2
  %rv3 = load i64, ptr %reg_ptr2, align 4
  %laddr = add i64 %rv3, 0
  %mem_end = add i64 %laddr, 8
  %in_range = icmp ule i64 %mem_end, %1
  br i1 %in_range, label %mem_ok, label %oob_trap

bb_0x100f8:                                       ; preds = %mem_ok10
  %reg_ptr27 = getelementptr i64, ptr %regs, i64 2
  %rv28 = load i64, ptr %reg_ptr27, align 4
  %laddr29 = add i64 %rv28, 0
  %mem_end30 = add i64 %laddr29, 8
  %in_range31 = icmp ule i64 %mem_end30, %1
  br i1 %in_range31, label %mem_ok32, label %oob_trap

bb_0x1010c:                                       ; preds = %mem_ok41
  %reg_ptr60 = getelementptr i64, ptr %regs, i64 2
  %rv61 = load i64, ptr %reg_ptr60, align 4
  %laddr62 = add i64 %rv61, 0
  %mem_end63 = add i64 %laddr62, 8
  %in_range64 = icmp ule i64 %mem_end63, %1
  br i1 %in_range64, label %mem_ok65, label %oob_trap

bb_0x10120:                                       ; preds = %mem_ok74
  %reg_ptr93 = getelementptr i64, ptr %regs, i64 2
  %rv94 = load i64, ptr %reg_ptr93, align 4
  %laddr95 = add i64 %rv94, 0
  %mem_end96 = add i64 %laddr95, 8
  %in_range97 = icmp ule i64 %mem_end96, %1
  br i1 %in_range97, label %mem_ok98, label %oob_trap

bb_0x10134:                                       ; preds = %mem_ok107
  %reg_ptr126 = getelementptr i64, ptr %regs, i64 0
  %rv127 = load i64, ptr %reg_ptr126, align 4
  %addi128 = add i64 %rv127, 1
  %reg_ptr129 = getelementptr i64, ptr %regs, i64 5
  store i64 %addi128, ptr %reg_ptr129, align 4
  %reg_ptr130 = getelementptr i64, ptr %regs, i64 0
  %rv131 = load i64, ptr %reg_ptr130, align 4
  %addi132 = add i64 %rv131, 4
  %reg_ptr133 = getelementptr i64, ptr %regs, i64 6
  store i64 %addi132, ptr %reg_ptr133, align 4
  %reg_ptr134 = getelementptr i64, ptr %regs, i64 2
  %rv135 = load i64, ptr %reg_ptr134, align 4
  %saddr = add i64 %rv135, 16
  %reg_ptr136 = getelementptr i64, ptr %regs, i64 5
  %rv137 = load i64, ptr %reg_ptr136, align 4
  %mem_end138 = add i64 %saddr, 8
  %in_range139 = icmp ule i64 %mem_end138, %1
  br i1 %in_range139, label %mem_ok140, label %oob_trap

bb_0x10158:                                       ; preds = %mem_ok165
  %reg_ptr184 = getelementptr i64, ptr %regs, i64 0
  %rv185 = load i64, ptr %reg_ptr184, align 4
  %addi186 = add i64 %rv185, -16
  %reg_ptr187 = getelementptr i64, ptr %regs, i64 5
  store i64 %addi186, ptr %reg_ptr187, align 4
  %reg_ptr188 = getelementptr i64, ptr %regs, i64 0
  %rv189 = load i64, ptr %reg_ptr188, align 4
  %addi190 = add i64 %rv189, 2
  %reg_ptr191 = getelementptr i64, ptr %regs, i64 6
  store i64 %addi190, ptr %reg_ptr191, align 4
  %reg_ptr192 = getelementptr i64, ptr %regs, i64 2
  %rv193 = load i64, ptr %reg_ptr192, align 4
  %saddr194 = add i64 %rv193, 32
  %reg_ptr195 = getelementptr i64, ptr %regs, i64 5
  %rv196 = load i64, ptr %reg_ptr195, align 4
  %mem_end197 = add i64 %saddr194, 8
  %in_range198 = icmp ule i64 %mem_end197, %1
  br i1 %in_range198, label %mem_ok199, label %oob_trap

bb_0x1017c:                                       ; preds = %mem_ok224
  %reg_ptr243 = getelementptr i64, ptr %regs, i64 2
  %rv244 = load i64, ptr %reg_ptr243, align 4
  %laddr245 = add i64 %rv244, 8
  %mem_end246 = add i64 %laddr245, 8
  %in_range247 = icmp ule i64 %mem_end246, %1
  br i1 %in_range247, label %mem_ok248, label %oob_trap

bb_0x10190:                                       ; preds = %mem_ok257
  %reg_ptr276 = getelementptr i64, ptr %regs, i64 2
  %rv277 = load i64, ptr %reg_ptr276, align 4
  %laddr278 = add i64 %rv277, 0
  %mem_end279 = add i64 %laddr278, 8
  %in_range280 = icmp ule i64 %mem_end279, %1
  br i1 %in_range280, label %mem_ok281, label %oob_trap

bb_0x101a4:                                       ; preds = %mem_ok290
  %reg_ptr311 = getelementptr i64, ptr %regs, i64 2
  %rv312 = load i64, ptr %reg_ptr311, align 4
  %laddr313 = add i64 %rv312, 8
  %mem_end314 = add i64 %laddr313, 8
  %in_range315 = icmp ule i64 %mem_end314, %1
  br i1 %in_range315, label %mem_ok316, label %oob_trap

bb_0x101b8:                                       ; preds = %mem_ok325
  %reg_ptr344 = getelementptr i64, ptr %regs, i64 0
  %rv345 = load i64, ptr %reg_ptr344, align 4
  %addi346 = add i64 %rv345, -1
  %reg_ptr347 = getelementptr i64, ptr %regs, i64 5
  store i64 %addi346, ptr %reg_ptr347, align 4
  %reg_ptr348 = getelementptr i64, ptr %regs, i64 2
  %rv349 = load i64, ptr %reg_ptr348, align 4
  %saddr350 = add i64 %rv349, 48
  %reg_ptr351 = getelementptr i64, ptr %regs, i64 5
  %rv352 = load i64, ptr %reg_ptr351, align 4
  %mem_end353 = add i64 %saddr350, 4
  %in_range354 = icmp ule i64 %mem_end353, %1
  br i1 %in_range354, label %mem_ok355, label %oob_trap

bb_0x101cc:                                       ; preds = %mem_ok362
  %reg_ptr374 = getelementptr i64, ptr %regs, i64 5
  store i64 -2147483648, ptr %reg_ptr374, align 4
  %reg_ptr375 = getelementptr i64, ptr %regs, i64 5
  %rv376 = load i64, ptr %reg_ptr375, align 4
  %src32 = trunc i64 %rv376 to i32
  %addiw = add i32 %src32, -1
  %addiw_sx = sext i32 %addiw to i64
  %reg_ptr377 = getelementptr i64, ptr %regs, i64 5
  store i64 %addiw_sx, ptr %reg_ptr377, align 4
  %reg_ptr378 = getelementptr i64, ptr %regs, i64 0
  %rv379 = load i64, ptr %reg_ptr378, align 4
  %addi380 = add i64 %rv379, 1
  %reg_ptr381 = getelementptr i64, ptr %regs, i64 6
  store i64 %addi380, ptr %reg_ptr381, align 4
  %reg_ptr382 = getelementptr i64, ptr %regs, i64 2
  %rv383 = load i64, ptr %reg_ptr382, align 4
  %saddr384 = add i64 %rv383, 48
  %reg_ptr385 = getelementptr i64, ptr %regs, i64 5
  %rv386 = load i64, ptr %reg_ptr385, align 4
  %mem_end387 = add i64 %saddr384, 4
  %in_range388 = icmp ule i64 %mem_end387, %1
  br i1 %in_range388, label %mem_ok389, label %oob_trap

bb_0x101f4:                                       ; preds = %mem_ok417
  %reg_ptr433 = getelementptr i64, ptr %regs, i64 2
  %rv434 = load i64, ptr %reg_ptr433, align 4
  %laddr435 = add i64 %rv434, 56
  %mem_end436 = add i64 %laddr435, 8
  %in_range437 = icmp ule i64 %mem_end436, %1
  br i1 %in_range437, label %mem_ok438, label %oob_trap

bb_0x10204:                                       ; No predecessors!
  %reg_ptr451 = getelementptr i64, ptr %regs, i64 0
  %rv452 = load i64, ptr %reg_ptr451, align 4
  %addi453 = add i64 %rv452, 1
  %reg_ptr454 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi453, ptr %reg_ptr454, align 4
  %reg_ptr455 = getelementptr i64, ptr %regs, i64 1
  store i64 66060, ptr %reg_ptr455, align 4
  br label %bb_0x100b0

bb_0x1020c:                                       ; preds = %mem_ok10
  %reg_ptr456 = getelementptr i64, ptr %regs, i64 0
  %rv457 = load i64, ptr %reg_ptr456, align 4
  %addi458 = add i64 %rv457, 2
  %reg_ptr459 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi458, ptr %reg_ptr459, align 4
  %reg_ptr460 = getelementptr i64, ptr %regs, i64 1
  store i64 66068, ptr %reg_ptr460, align 4
  br label %bb_0x100b0

bb_0x10214:                                       ; preds = %mem_ok41
  %reg_ptr461 = getelementptr i64, ptr %regs, i64 0
  %rv462 = load i64, ptr %reg_ptr461, align 4
  %addi463 = add i64 %rv462, 3
  %reg_ptr464 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi463, ptr %reg_ptr464, align 4
  %reg_ptr465 = getelementptr i64, ptr %regs, i64 1
  store i64 66076, ptr %reg_ptr465, align 4
  br label %bb_0x100b0

bb_0x1021c:                                       ; preds = %mem_ok74
  %reg_ptr466 = getelementptr i64, ptr %regs, i64 0
  %rv467 = load i64, ptr %reg_ptr466, align 4
  %addi468 = add i64 %rv467, 4
  %reg_ptr469 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi468, ptr %reg_ptr469, align 4
  %reg_ptr470 = getelementptr i64, ptr %regs, i64 1
  store i64 66084, ptr %reg_ptr470, align 4
  br label %bb_0x100b0

bb_0x10224:                                       ; preds = %mem_ok107
  %reg_ptr471 = getelementptr i64, ptr %regs, i64 0
  %rv472 = load i64, ptr %reg_ptr471, align 4
  %addi473 = add i64 %rv472, 5
  %reg_ptr474 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi473, ptr %reg_ptr474, align 4
  %reg_ptr475 = getelementptr i64, ptr %regs, i64 1
  store i64 66092, ptr %reg_ptr475, align 4
  br label %bb_0x100b0

bb_0x1022c:                                       ; preds = %mem_ok165
  %reg_ptr476 = getelementptr i64, ptr %regs, i64 0
  %rv477 = load i64, ptr %reg_ptr476, align 4
  %addi478 = add i64 %rv477, 6
  %reg_ptr479 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi478, ptr %reg_ptr479, align 4
  %reg_ptr480 = getelementptr i64, ptr %regs, i64 1
  store i64 66100, ptr %reg_ptr480, align 4
  br label %bb_0x100b0

bb_0x10234:                                       ; preds = %mem_ok224
  %reg_ptr481 = getelementptr i64, ptr %regs, i64 0
  %rv482 = load i64, ptr %reg_ptr481, align 4
  %addi483 = add i64 %rv482, 7
  %reg_ptr484 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi483, ptr %reg_ptr484, align 4
  %reg_ptr485 = getelementptr i64, ptr %regs, i64 1
  store i64 66108, ptr %reg_ptr485, align 4
  br label %bb_0x100b0

bb_0x1023c:                                       ; preds = %mem_ok257
  %reg_ptr486 = getelementptr i64, ptr %regs, i64 0
  %rv487 = load i64, ptr %reg_ptr486, align 4
  %addi488 = add i64 %rv487, 8
  %reg_ptr489 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi488, ptr %reg_ptr489, align 4
  %reg_ptr490 = getelementptr i64, ptr %regs, i64 1
  store i64 66116, ptr %reg_ptr490, align 4
  br label %bb_0x100b0

bb_0x10244:                                       ; preds = %mem_ok290
  %reg_ptr491 = getelementptr i64, ptr %regs, i64 0
  %rv492 = load i64, ptr %reg_ptr491, align 4
  %addi493 = add i64 %rv492, 9
  %reg_ptr494 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi493, ptr %reg_ptr494, align 4
  %reg_ptr495 = getelementptr i64, ptr %regs, i64 1
  store i64 66124, ptr %reg_ptr495, align 4
  br label %bb_0x100b0

bb_0x1024c:                                       ; preds = %mem_ok325
  %reg_ptr496 = getelementptr i64, ptr %regs, i64 0
  %rv497 = load i64, ptr %reg_ptr496, align 4
  %addi498 = add i64 %rv497, 10
  %reg_ptr499 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi498, ptr %reg_ptr499, align 4
  %reg_ptr500 = getelementptr i64, ptr %regs, i64 1
  store i64 66132, ptr %reg_ptr500, align 4
  br label %bb_0x100b0

bb_0x10254:                                       ; preds = %mem_ok362
  %reg_ptr501 = getelementptr i64, ptr %regs, i64 0
  %rv502 = load i64, ptr %reg_ptr501, align 4
  %addi503 = add i64 %rv502, 11
  %reg_ptr504 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi503, ptr %reg_ptr504, align 4
  %reg_ptr505 = getelementptr i64, ptr %regs, i64 1
  store i64 66140, ptr %reg_ptr505, align 4
  br label %bb_0x100b0

bb_0x1025c:                                       ; preds = %mem_ok417
  %reg_ptr506 = getelementptr i64, ptr %regs, i64 0
  %rv507 = load i64, ptr %reg_ptr506, align 4
  %addi508 = add i64 %rv507, 12
  %reg_ptr509 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi508, ptr %reg_ptr509, align 4
  %reg_ptr510 = getelementptr i64, ptr %regs, i64 1
  store i64 66148, ptr %reg_ptr510, align 4
  br label %bb_0x100b0

bb_0x10264:                                       ; No predecessors!
  unreachable

oob_trap:                                         ; preds = %bb_0x101f4, %mem_ok407, %mem_ok399, %mem_ok389, %bb_0x101cc, %mem_ok355, %bb_0x101b8, %mem_ok316, %bb_0x101a4, %mem_ok281, %bb_0x10190, %mem_ok248, %bb_0x1017c, %mem_ok215, %mem_ok208, %mem_ok199, %bb_0x10158, %mem_ok156, %mem_ok149, %mem_ok140, %bb_0x10134, %mem_ok98, %bb_0x10120, %mem_ok65, %bb_0x1010c, %mem_ok32, %bb_0x100f8, %mem_ok, %bb_0x100e4
  ret i32 1

ecall_exit:                                       ; preds = %bb_0x100b0
  ret i32 %ecall_ret

ecall_cont:                                       ; preds = %bb_0x100b0
  br label %bb_0x100b8

mem_ok:                                           ; preds = %bb_0x100e4
  %mem_ptr = getelementptr i8, ptr %0, i64 %laddr
  %ld = load i64, ptr %mem_ptr, align 4
  %reg_ptr4 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld, ptr %reg_ptr4, align 4
  %reg_ptr5 = getelementptr i64, ptr %regs, i64 2
  %rv6 = load i64, ptr %reg_ptr5, align 4
  %laddr7 = add i64 %rv6, 8
  %mem_end8 = add i64 %laddr7, 8
  %in_range9 = icmp ule i64 %mem_end8, %1
  br i1 %in_range9, label %mem_ok10, label %oob_trap

mem_ok10:                                         ; preds = %mem_ok
  %mem_ptr11 = getelementptr i8, ptr %0, i64 %laddr7
  %ld12 = load i64, ptr %mem_ptr11, align 4
  %reg_ptr13 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld12, ptr %reg_ptr13, align 4
  %reg_ptr14 = getelementptr i64, ptr %regs, i64 5
  %rv15 = load i64, ptr %reg_ptr14, align 4
  %reg_ptr16 = getelementptr i64, ptr %regs, i64 6
  %rv17 = load i64, ptr %reg_ptr16, align 4
  %sh6 = and i64 %rv17, 63
  %sub = sub i64 %rv15, %rv17
  %reg_ptr18 = getelementptr i64, ptr %regs, i64 7
  store i64 %sub, ptr %reg_ptr18, align 4
  %reg_ptr19 = getelementptr i64, ptr %regs, i64 0
  %rv20 = load i64, ptr %reg_ptr19, align 4
  %addi21 = add i64 %rv20, 4
  %reg_ptr22 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi21, ptr %reg_ptr22, align 4
  %reg_ptr23 = getelementptr i64, ptr %regs, i64 7
  %rv24 = load i64, ptr %reg_ptr23, align 4
  %reg_ptr25 = getelementptr i64, ptr %regs, i64 28
  %rv26 = load i64, ptr %reg_ptr25, align 4
  %bne = icmp ne i64 %rv24, %rv26
  br i1 %bne, label %bb_0x1020c, label %bb_0x100f8

mem_ok32:                                         ; preds = %bb_0x100f8
  %mem_ptr33 = getelementptr i8, ptr %0, i64 %laddr29
  %ld34 = load i64, ptr %mem_ptr33, align 4
  %reg_ptr35 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld34, ptr %reg_ptr35, align 4
  %reg_ptr36 = getelementptr i64, ptr %regs, i64 2
  %rv37 = load i64, ptr %reg_ptr36, align 4
  %laddr38 = add i64 %rv37, 8
  %mem_end39 = add i64 %laddr38, 8
  %in_range40 = icmp ule i64 %mem_end39, %1
  br i1 %in_range40, label %mem_ok41, label %oob_trap

mem_ok41:                                         ; preds = %mem_ok32
  %mem_ptr42 = getelementptr i8, ptr %0, i64 %laddr38
  %ld43 = load i64, ptr %mem_ptr42, align 4
  %reg_ptr44 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld43, ptr %reg_ptr44, align 4
  %reg_ptr45 = getelementptr i64, ptr %regs, i64 5
  %rv46 = load i64, ptr %reg_ptr45, align 4
  %reg_ptr47 = getelementptr i64, ptr %regs, i64 6
  %rv48 = load i64, ptr %reg_ptr47, align 4
  %sh649 = and i64 %rv48, 63
  %and = and i64 %rv46, %rv48
  %reg_ptr50 = getelementptr i64, ptr %regs, i64 7
  store i64 %and, ptr %reg_ptr50, align 4
  %reg_ptr51 = getelementptr i64, ptr %regs, i64 0
  %rv52 = load i64, ptr %reg_ptr51, align 4
  %addi53 = add i64 %rv52, 3
  %reg_ptr54 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi53, ptr %reg_ptr54, align 4
  %reg_ptr55 = getelementptr i64, ptr %regs, i64 7
  %rv56 = load i64, ptr %reg_ptr55, align 4
  %reg_ptr57 = getelementptr i64, ptr %regs, i64 28
  %rv58 = load i64, ptr %reg_ptr57, align 4
  %bne59 = icmp ne i64 %rv56, %rv58
  br i1 %bne59, label %bb_0x10214, label %bb_0x1010c

mem_ok65:                                         ; preds = %bb_0x1010c
  %mem_ptr66 = getelementptr i8, ptr %0, i64 %laddr62
  %ld67 = load i64, ptr %mem_ptr66, align 4
  %reg_ptr68 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld67, ptr %reg_ptr68, align 4
  %reg_ptr69 = getelementptr i64, ptr %regs, i64 2
  %rv70 = load i64, ptr %reg_ptr69, align 4
  %laddr71 = add i64 %rv70, 8
  %mem_end72 = add i64 %laddr71, 8
  %in_range73 = icmp ule i64 %mem_end72, %1
  br i1 %in_range73, label %mem_ok74, label %oob_trap

mem_ok74:                                         ; preds = %mem_ok65
  %mem_ptr75 = getelementptr i8, ptr %0, i64 %laddr71
  %ld76 = load i64, ptr %mem_ptr75, align 4
  %reg_ptr77 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld76, ptr %reg_ptr77, align 4
  %reg_ptr78 = getelementptr i64, ptr %regs, i64 5
  %rv79 = load i64, ptr %reg_ptr78, align 4
  %reg_ptr80 = getelementptr i64, ptr %regs, i64 6
  %rv81 = load i64, ptr %reg_ptr80, align 4
  %sh682 = and i64 %rv81, 63
  %or = or i64 %rv79, %rv81
  %reg_ptr83 = getelementptr i64, ptr %regs, i64 7
  store i64 %or, ptr %reg_ptr83, align 4
  %reg_ptr84 = getelementptr i64, ptr %regs, i64 0
  %rv85 = load i64, ptr %reg_ptr84, align 4
  %addi86 = add i64 %rv85, 7
  %reg_ptr87 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi86, ptr %reg_ptr87, align 4
  %reg_ptr88 = getelementptr i64, ptr %regs, i64 7
  %rv89 = load i64, ptr %reg_ptr88, align 4
  %reg_ptr90 = getelementptr i64, ptr %regs, i64 28
  %rv91 = load i64, ptr %reg_ptr90, align 4
  %bne92 = icmp ne i64 %rv89, %rv91
  br i1 %bne92, label %bb_0x1021c, label %bb_0x10120

mem_ok98:                                         ; preds = %bb_0x10120
  %mem_ptr99 = getelementptr i8, ptr %0, i64 %laddr95
  %ld100 = load i64, ptr %mem_ptr99, align 4
  %reg_ptr101 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld100, ptr %reg_ptr101, align 4
  %reg_ptr102 = getelementptr i64, ptr %regs, i64 2
  %rv103 = load i64, ptr %reg_ptr102, align 4
  %laddr104 = add i64 %rv103, 8
  %mem_end105 = add i64 %laddr104, 8
  %in_range106 = icmp ule i64 %mem_end105, %1
  br i1 %in_range106, label %mem_ok107, label %oob_trap

mem_ok107:                                        ; preds = %mem_ok98
  %mem_ptr108 = getelementptr i8, ptr %0, i64 %laddr104
  %ld109 = load i64, ptr %mem_ptr108, align 4
  %reg_ptr110 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld109, ptr %reg_ptr110, align 4
  %reg_ptr111 = getelementptr i64, ptr %regs, i64 5
  %rv112 = load i64, ptr %reg_ptr111, align 4
  %reg_ptr113 = getelementptr i64, ptr %regs, i64 6
  %rv114 = load i64, ptr %reg_ptr113, align 4
  %sh6115 = and i64 %rv114, 63
  %xor = xor i64 %rv112, %rv114
  %reg_ptr116 = getelementptr i64, ptr %regs, i64 7
  store i64 %xor, ptr %reg_ptr116, align 4
  %reg_ptr117 = getelementptr i64, ptr %regs, i64 0
  %rv118 = load i64, ptr %reg_ptr117, align 4
  %addi119 = add i64 %rv118, 4
  %reg_ptr120 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi119, ptr %reg_ptr120, align 4
  %reg_ptr121 = getelementptr i64, ptr %regs, i64 7
  %rv122 = load i64, ptr %reg_ptr121, align 4
  %reg_ptr123 = getelementptr i64, ptr %regs, i64 28
  %rv124 = load i64, ptr %reg_ptr123, align 4
  %bne125 = icmp ne i64 %rv122, %rv124
  br i1 %bne125, label %bb_0x10224, label %bb_0x10134

mem_ok140:                                        ; preds = %bb_0x10134
  %mem_ptr141 = getelementptr i8, ptr %0, i64 %saddr
  store i64 %rv137, ptr %mem_ptr141, align 4
  %reg_ptr142 = getelementptr i64, ptr %regs, i64 2
  %rv143 = load i64, ptr %reg_ptr142, align 4
  %saddr144 = add i64 %rv143, 24
  %reg_ptr145 = getelementptr i64, ptr %regs, i64 6
  %rv146 = load i64, ptr %reg_ptr145, align 4
  %mem_end147 = add i64 %saddr144, 8
  %in_range148 = icmp ule i64 %mem_end147, %1
  br i1 %in_range148, label %mem_ok149, label %oob_trap

mem_ok149:                                        ; preds = %mem_ok140
  %mem_ptr150 = getelementptr i8, ptr %0, i64 %saddr144
  store i64 %rv146, ptr %mem_ptr150, align 4
  %reg_ptr151 = getelementptr i64, ptr %regs, i64 2
  %rv152 = load i64, ptr %reg_ptr151, align 4
  %laddr153 = add i64 %rv152, 16
  %mem_end154 = add i64 %laddr153, 8
  %in_range155 = icmp ule i64 %mem_end154, %1
  br i1 %in_range155, label %mem_ok156, label %oob_trap

mem_ok156:                                        ; preds = %mem_ok149
  %mem_ptr157 = getelementptr i8, ptr %0, i64 %laddr153
  %ld158 = load i64, ptr %mem_ptr157, align 4
  %reg_ptr159 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld158, ptr %reg_ptr159, align 4
  %reg_ptr160 = getelementptr i64, ptr %regs, i64 2
  %rv161 = load i64, ptr %reg_ptr160, align 4
  %laddr162 = add i64 %rv161, 24
  %mem_end163 = add i64 %laddr162, 8
  %in_range164 = icmp ule i64 %mem_end163, %1
  br i1 %in_range164, label %mem_ok165, label %oob_trap

mem_ok165:                                        ; preds = %mem_ok156
  %mem_ptr166 = getelementptr i8, ptr %0, i64 %laddr162
  %ld167 = load i64, ptr %mem_ptr166, align 4
  %reg_ptr168 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld167, ptr %reg_ptr168, align 4
  %reg_ptr169 = getelementptr i64, ptr %regs, i64 5
  %rv170 = load i64, ptr %reg_ptr169, align 4
  %reg_ptr171 = getelementptr i64, ptr %regs, i64 6
  %rv172 = load i64, ptr %reg_ptr171, align 4
  %sh6173 = and i64 %rv172, 63
  %sll = shl i64 %rv170, %sh6173
  %reg_ptr174 = getelementptr i64, ptr %regs, i64 7
  store i64 %sll, ptr %reg_ptr174, align 4
  %reg_ptr175 = getelementptr i64, ptr %regs, i64 0
  %rv176 = load i64, ptr %reg_ptr175, align 4
  %addi177 = add i64 %rv176, 16
  %reg_ptr178 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi177, ptr %reg_ptr178, align 4
  %reg_ptr179 = getelementptr i64, ptr %regs, i64 7
  %rv180 = load i64, ptr %reg_ptr179, align 4
  %reg_ptr181 = getelementptr i64, ptr %regs, i64 28
  %rv182 = load i64, ptr %reg_ptr181, align 4
  %bne183 = icmp ne i64 %rv180, %rv182
  br i1 %bne183, label %bb_0x1022c, label %bb_0x10158

mem_ok199:                                        ; preds = %bb_0x10158
  %mem_ptr200 = getelementptr i8, ptr %0, i64 %saddr194
  store i64 %rv196, ptr %mem_ptr200, align 4
  %reg_ptr201 = getelementptr i64, ptr %regs, i64 2
  %rv202 = load i64, ptr %reg_ptr201, align 4
  %saddr203 = add i64 %rv202, 40
  %reg_ptr204 = getelementptr i64, ptr %regs, i64 6
  %rv205 = load i64, ptr %reg_ptr204, align 4
  %mem_end206 = add i64 %saddr203, 8
  %in_range207 = icmp ule i64 %mem_end206, %1
  br i1 %in_range207, label %mem_ok208, label %oob_trap

mem_ok208:                                        ; preds = %mem_ok199
  %mem_ptr209 = getelementptr i8, ptr %0, i64 %saddr203
  store i64 %rv205, ptr %mem_ptr209, align 4
  %reg_ptr210 = getelementptr i64, ptr %regs, i64 2
  %rv211 = load i64, ptr %reg_ptr210, align 4
  %laddr212 = add i64 %rv211, 32
  %mem_end213 = add i64 %laddr212, 8
  %in_range214 = icmp ule i64 %mem_end213, %1
  br i1 %in_range214, label %mem_ok215, label %oob_trap

mem_ok215:                                        ; preds = %mem_ok208
  %mem_ptr216 = getelementptr i8, ptr %0, i64 %laddr212
  %ld217 = load i64, ptr %mem_ptr216, align 4
  %reg_ptr218 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld217, ptr %reg_ptr218, align 4
  %reg_ptr219 = getelementptr i64, ptr %regs, i64 2
  %rv220 = load i64, ptr %reg_ptr219, align 4
  %laddr221 = add i64 %rv220, 40
  %mem_end222 = add i64 %laddr221, 8
  %in_range223 = icmp ule i64 %mem_end222, %1
  br i1 %in_range223, label %mem_ok224, label %oob_trap

mem_ok224:                                        ; preds = %mem_ok215
  %mem_ptr225 = getelementptr i8, ptr %0, i64 %laddr221
  %ld226 = load i64, ptr %mem_ptr225, align 4
  %reg_ptr227 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld226, ptr %reg_ptr227, align 4
  %reg_ptr228 = getelementptr i64, ptr %regs, i64 5
  %rv229 = load i64, ptr %reg_ptr228, align 4
  %reg_ptr230 = getelementptr i64, ptr %regs, i64 6
  %rv231 = load i64, ptr %reg_ptr230, align 4
  %sh6232 = and i64 %rv231, 63
  %sra = ashr i64 %rv229, %sh6232
  %reg_ptr233 = getelementptr i64, ptr %regs, i64 7
  store i64 %sra, ptr %reg_ptr233, align 4
  %reg_ptr234 = getelementptr i64, ptr %regs, i64 0
  %rv235 = load i64, ptr %reg_ptr234, align 4
  %addi236 = add i64 %rv235, -4
  %reg_ptr237 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi236, ptr %reg_ptr237, align 4
  %reg_ptr238 = getelementptr i64, ptr %regs, i64 7
  %rv239 = load i64, ptr %reg_ptr238, align 4
  %reg_ptr240 = getelementptr i64, ptr %regs, i64 28
  %rv241 = load i64, ptr %reg_ptr240, align 4
  %bne242 = icmp ne i64 %rv239, %rv241
  br i1 %bne242, label %bb_0x10234, label %bb_0x1017c

mem_ok248:                                        ; preds = %bb_0x1017c
  %mem_ptr249 = getelementptr i8, ptr %0, i64 %laddr245
  %ld250 = load i64, ptr %mem_ptr249, align 4
  %reg_ptr251 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld250, ptr %reg_ptr251, align 4
  %reg_ptr252 = getelementptr i64, ptr %regs, i64 2
  %rv253 = load i64, ptr %reg_ptr252, align 4
  %laddr254 = add i64 %rv253, 0
  %mem_end255 = add i64 %laddr254, 8
  %in_range256 = icmp ule i64 %mem_end255, %1
  br i1 %in_range256, label %mem_ok257, label %oob_trap

mem_ok257:                                        ; preds = %mem_ok248
  %mem_ptr258 = getelementptr i8, ptr %0, i64 %laddr254
  %ld259 = load i64, ptr %mem_ptr258, align 4
  %reg_ptr260 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld259, ptr %reg_ptr260, align 4
  %reg_ptr261 = getelementptr i64, ptr %regs, i64 5
  %rv262 = load i64, ptr %reg_ptr261, align 4
  %reg_ptr263 = getelementptr i64, ptr %regs, i64 6
  %rv264 = load i64, ptr %reg_ptr263, align 4
  %sh6265 = and i64 %rv264, 63
  %slt = icmp slt i64 %rv262, %rv264
  %slt_z = zext i1 %slt to i64
  %reg_ptr266 = getelementptr i64, ptr %regs, i64 7
  store i64 %slt_z, ptr %reg_ptr266, align 4
  %reg_ptr267 = getelementptr i64, ptr %regs, i64 0
  %rv268 = load i64, ptr %reg_ptr267, align 4
  %addi269 = add i64 %rv268, 1
  %reg_ptr270 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi269, ptr %reg_ptr270, align 4
  %reg_ptr271 = getelementptr i64, ptr %regs, i64 7
  %rv272 = load i64, ptr %reg_ptr271, align 4
  %reg_ptr273 = getelementptr i64, ptr %regs, i64 28
  %rv274 = load i64, ptr %reg_ptr273, align 4
  %bne275 = icmp ne i64 %rv272, %rv274
  br i1 %bne275, label %bb_0x1023c, label %bb_0x10190

mem_ok281:                                        ; preds = %bb_0x10190
  %mem_ptr282 = getelementptr i8, ptr %0, i64 %laddr278
  %ld283 = load i64, ptr %mem_ptr282, align 4
  %reg_ptr284 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld283, ptr %reg_ptr284, align 4
  %reg_ptr285 = getelementptr i64, ptr %regs, i64 2
  %rv286 = load i64, ptr %reg_ptr285, align 4
  %laddr287 = add i64 %rv286, 8
  %mem_end288 = add i64 %laddr287, 8
  %in_range289 = icmp ule i64 %mem_end288, %1
  br i1 %in_range289, label %mem_ok290, label %oob_trap

mem_ok290:                                        ; preds = %mem_ok281
  %mem_ptr291 = getelementptr i8, ptr %0, i64 %laddr287
  %ld292 = load i64, ptr %mem_ptr291, align 4
  %reg_ptr293 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld292, ptr %reg_ptr293, align 4
  %reg_ptr294 = getelementptr i64, ptr %regs, i64 5
  %rv295 = load i64, ptr %reg_ptr294, align 4
  %reg_ptr296 = getelementptr i64, ptr %regs, i64 6
  %rv297 = load i64, ptr %reg_ptr296, align 4
  %sh6298 = and i64 %rv297, 63
  %slt299 = icmp slt i64 %rv295, %rv297
  %slt_z300 = zext i1 %slt299 to i64
  %reg_ptr301 = getelementptr i64, ptr %regs, i64 7
  store i64 %slt_z300, ptr %reg_ptr301, align 4
  %reg_ptr302 = getelementptr i64, ptr %regs, i64 0
  %rv303 = load i64, ptr %reg_ptr302, align 4
  %addi304 = add i64 %rv303, 0
  %reg_ptr305 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi304, ptr %reg_ptr305, align 4
  %reg_ptr306 = getelementptr i64, ptr %regs, i64 7
  %rv307 = load i64, ptr %reg_ptr306, align 4
  %reg_ptr308 = getelementptr i64, ptr %regs, i64 28
  %rv309 = load i64, ptr %reg_ptr308, align 4
  %bne310 = icmp ne i64 %rv307, %rv309
  br i1 %bne310, label %bb_0x10244, label %bb_0x101a4

mem_ok316:                                        ; preds = %bb_0x101a4
  %mem_ptr317 = getelementptr i8, ptr %0, i64 %laddr313
  %ld318 = load i64, ptr %mem_ptr317, align 4
  %reg_ptr319 = getelementptr i64, ptr %regs, i64 5
  store i64 %ld318, ptr %reg_ptr319, align 4
  %reg_ptr320 = getelementptr i64, ptr %regs, i64 2
  %rv321 = load i64, ptr %reg_ptr320, align 4
  %laddr322 = add i64 %rv321, 0
  %mem_end323 = add i64 %laddr322, 8
  %in_range324 = icmp ule i64 %mem_end323, %1
  br i1 %in_range324, label %mem_ok325, label %oob_trap

mem_ok325:                                        ; preds = %mem_ok316
  %mem_ptr326 = getelementptr i8, ptr %0, i64 %laddr322
  %ld327 = load i64, ptr %mem_ptr326, align 4
  %reg_ptr328 = getelementptr i64, ptr %regs, i64 6
  store i64 %ld327, ptr %reg_ptr328, align 4
  %reg_ptr329 = getelementptr i64, ptr %regs, i64 5
  %rv330 = load i64, ptr %reg_ptr329, align 4
  %reg_ptr331 = getelementptr i64, ptr %regs, i64 6
  %rv332 = load i64, ptr %reg_ptr331, align 4
  %sh6333 = and i64 %rv332, 63
  %sltu = icmp ult i64 %rv330, %rv332
  %sltu_z = zext i1 %sltu to i64
  %reg_ptr334 = getelementptr i64, ptr %regs, i64 7
  store i64 %sltu_z, ptr %reg_ptr334, align 4
  %reg_ptr335 = getelementptr i64, ptr %regs, i64 0
  %rv336 = load i64, ptr %reg_ptr335, align 4
  %addi337 = add i64 %rv336, 1
  %reg_ptr338 = getelementptr i64, ptr %regs, i64 28
  store i64 %addi337, ptr %reg_ptr338, align 4
  %reg_ptr339 = getelementptr i64, ptr %regs, i64 7
  %rv340 = load i64, ptr %reg_ptr339, align 4
  %reg_ptr341 = getelementptr i64, ptr %regs, i64 28
  %rv342 = load i64, ptr %reg_ptr341, align 4
  %bne343 = icmp ne i64 %rv340, %rv342
  br i1 %bne343, label %bb_0x1024c, label %bb_0x101b8

mem_ok355:                                        ; preds = %bb_0x101b8
  %mem_ptr356 = getelementptr i8, ptr %0, i64 %saddr350
  %sv32 = trunc i64 %rv352 to i32
  store i32 %sv32, ptr %mem_ptr356, align 4
  %reg_ptr357 = getelementptr i64, ptr %regs, i64 2
  %rv358 = load i64, ptr %reg_ptr357, align 4
  %laddr359 = add i64 %rv358, 48
  %mem_end360 = add i64 %laddr359, 4
  %in_range361 = icmp ule i64 %mem_end360, %1
  br i1 %in_range361, label %mem_ok362, label %oob_trap

mem_ok362:                                        ; preds = %mem_ok355
  %mem_ptr363 = getelementptr i8, ptr %0, i64 %laddr359
  %lv32 = load i32, ptr %mem_ptr363, align 4
  %lw = sext i32 %lv32 to i64
  %reg_ptr364 = getelementptr i64, ptr %regs, i64 6
  store i64 %lw, ptr %reg_ptr364, align 4
  %reg_ptr365 = getelementptr i64, ptr %regs, i64 0
  %rv366 = load i64, ptr %reg_ptr365, align 4
  %addi367 = add i64 %rv366, -1
  %reg_ptr368 = getelementptr i64, ptr %regs, i64 7
  store i64 %addi367, ptr %reg_ptr368, align 4
  %reg_ptr369 = getelementptr i64, ptr %regs, i64 6
  %rv370 = load i64, ptr %reg_ptr369, align 4
  %reg_ptr371 = getelementptr i64, ptr %regs, i64 7
  %rv372 = load i64, ptr %reg_ptr371, align 4
  %bne373 = icmp ne i64 %rv370, %rv372
  br i1 %bne373, label %bb_0x10254, label %bb_0x101cc

mem_ok389:                                        ; preds = %bb_0x101cc
  %mem_ptr390 = getelementptr i8, ptr %0, i64 %saddr384
  %sv32391 = trunc i64 %rv386 to i32
  store i32 %sv32391, ptr %mem_ptr390, align 4
  %reg_ptr392 = getelementptr i64, ptr %regs, i64 2
  %rv393 = load i64, ptr %reg_ptr392, align 4
  %saddr394 = add i64 %rv393, 52
  %reg_ptr395 = getelementptr i64, ptr %regs, i64 6
  %rv396 = load i64, ptr %reg_ptr395, align 4
  %mem_end397 = add i64 %saddr394, 4
  %in_range398 = icmp ule i64 %mem_end397, %1
  br i1 %in_range398, label %mem_ok399, label %oob_trap

mem_ok399:                                        ; preds = %mem_ok389
  %mem_ptr400 = getelementptr i8, ptr %0, i64 %saddr394
  %sv32401 = trunc i64 %rv396 to i32
  store i32 %sv32401, ptr %mem_ptr400, align 4
  %reg_ptr402 = getelementptr i64, ptr %regs, i64 2
  %rv403 = load i64, ptr %reg_ptr402, align 4
  %laddr404 = add i64 %rv403, 48
  %mem_end405 = add i64 %laddr404, 4
  %in_range406 = icmp ule i64 %mem_end405, %1
  br i1 %in_range406, label %mem_ok407, label %oob_trap

mem_ok407:                                        ; preds = %mem_ok399
  %mem_ptr408 = getelementptr i8, ptr %0, i64 %laddr404
  %lv32409 = load i32, ptr %mem_ptr408, align 4
  %lw410 = sext i32 %lv32409 to i64
  %reg_ptr411 = getelementptr i64, ptr %regs, i64 5
  store i64 %lw410, ptr %reg_ptr411, align 4
  %reg_ptr412 = getelementptr i64, ptr %regs, i64 2
  %rv413 = load i64, ptr %reg_ptr412, align 4
  %laddr414 = add i64 %rv413, 52
  %mem_end415 = add i64 %laddr414, 4
  %in_range416 = icmp ule i64 %mem_end415, %1
  br i1 %in_range416, label %mem_ok417, label %oob_trap

mem_ok417:                                        ; preds = %mem_ok407
  %mem_ptr418 = getelementptr i8, ptr %0, i64 %laddr414
  %lv32419 = load i32, ptr %mem_ptr418, align 4
  %lw420 = sext i32 %lv32419 to i64
  %reg_ptr421 = getelementptr i64, ptr %regs, i64 6
  store i64 %lw420, ptr %reg_ptr421, align 4
  %reg_ptr422 = getelementptr i64, ptr %regs, i64 5
  %rv423 = load i64, ptr %reg_ptr422, align 4
  %v1_32 = trunc i64 %rv423 to i32
  %reg_ptr424 = getelementptr i64, ptr %regs, i64 6
  %rv425 = load i64, ptr %reg_ptr424, align 4
  %v2_32 = trunc i64 %rv425 to i32
  %sh5 = and i32 %v2_32, 31
  %addw = add i32 %v1_32, %v2_32
  %op32_sx = sext i32 %addw to i64
  %reg_ptr426 = getelementptr i64, ptr %regs, i64 7
  store i64 %op32_sx, ptr %reg_ptr426, align 4
  %reg_ptr427 = getelementptr i64, ptr %regs, i64 28
  store i64 -2147483648, ptr %reg_ptr427, align 4
  %reg_ptr428 = getelementptr i64, ptr %regs, i64 7
  %rv429 = load i64, ptr %reg_ptr428, align 4
  %reg_ptr430 = getelementptr i64, ptr %regs, i64 28
  %rv431 = load i64, ptr %reg_ptr430, align 4
  %bne432 = icmp ne i64 %rv429, %rv431
  br i1 %bne432, label %bb_0x1025c, label %bb_0x101f4

mem_ok438:                                        ; preds = %bb_0x101f4
  %mem_ptr439 = getelementptr i8, ptr %0, i64 %laddr435
  %ld440 = load i64, ptr %mem_ptr439, align 4
  %reg_ptr441 = getelementptr i64, ptr %regs, i64 1
  store i64 %ld440, ptr %reg_ptr441, align 4
  %reg_ptr442 = getelementptr i64, ptr %regs, i64 2
  %rv443 = load i64, ptr %reg_ptr442, align 4
  %addi444 = add i64 %rv443, 64
  %reg_ptr445 = getelementptr i64, ptr %regs, i64 2
  store i64 %addi444, ptr %reg_ptr445, align 4
  %reg_ptr446 = getelementptr i64, ptr %regs, i64 0
  %rv447 = load i64, ptr %reg_ptr446, align 4
  %addi448 = add i64 %rv447, 0
  %reg_ptr449 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi448, ptr %reg_ptr449, align 4
  %reg_ptr450 = getelementptr i64, ptr %regs, i64 1
  store i64 66052, ptr %reg_ptr450, align 4
  br label %bb_0x100b0
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #0

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: write) }
