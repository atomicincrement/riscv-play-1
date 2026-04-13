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
  br label %bb_0x1014c

bb_0x1014c:                                       ; preds = %ecall_cont, %alloca
  br label %bb_0x10144

bb_0x10144:                                       ; preds = %bb_0x10278, %bb_0x10270, %bb_0x10268, %bb_0x10260, %bb_0x10258, %bb_0x10250, %bb_0x10248, %bb_0x10240, %bb_0x10238, %bb_0x10230, %bb_0x1014c
  %reg_ptr = getelementptr i64, ptr %regs, i64 0
  %rv = load i64, ptr %reg_ptr, align 4
  %addi = add i64 %rv, 93
  %reg_ptr1 = getelementptr i64, ptr %regs, i64 17
  store i64 %addi, ptr %reg_ptr1, align 4
  %ecall_ret = call i32 @jit_ecall(ptr %regs, ptr %0, i64 %1)
  %is_exit = icmp sge i32 %ecall_ret, 0
  br i1 %is_exit, label %ecall_exit, label %ecall_cont

bb_0x10178:                                       ; No predecessors!
  %reg_ptr2 = getelementptr i64, ptr %regs, i64 2
  %rv3 = load i64, ptr %reg_ptr2, align 4
  %laddr = add i64 %rv3, 40
  %mem_end = add i64 %laddr, 8
  %in_range = icmp ule i64 %mem_end, %1
  br i1 %in_range, label %mem_ok, label %oob_trap

bb_0x10188:                                       ; preds = %mem_ok10
  %reg_ptr22 = getelementptr i64, ptr %regs, i64 2
  %rv23 = load i64, ptr %reg_ptr22, align 4
  %laddr24 = add i64 %rv23, 40
  %mem_end25 = add i64 %laddr24, 8
  %in_range26 = icmp ule i64 %mem_end25, %1
  br i1 %in_range26, label %mem_ok27, label %oob_trap

bb_0x1019c:                                       ; preds = %mem_ok36
  %reg_ptr54 = getelementptr i64, ptr %regs, i64 2
  %rv55 = load i64, ptr %reg_ptr54, align 4
  %laddr56 = add i64 %rv55, 40
  %mem_end57 = add i64 %laddr56, 8
  %in_range58 = icmp ule i64 %mem_end57, %1
  br i1 %in_range58, label %mem_ok59, label %oob_trap

bb_0x101b0:                                       ; preds = %mem_ok68
  %reg_ptr87 = getelementptr i64, ptr %regs, i64 2
  %rv88 = load i64, ptr %reg_ptr87, align 4
  %laddr89 = add i64 %rv88, 40
  %mem_end90 = add i64 %laddr89, 8
  %in_range91 = icmp ule i64 %mem_end90, %1
  br i1 %in_range91, label %mem_ok92, label %oob_trap

bb_0x101c4:                                       ; preds = %mem_ok101
  %reg_ptr120 = getelementptr i64, ptr %regs, i64 0
  %rv121 = load i64, ptr %reg_ptr120, align 4
  %addi122 = add i64 %rv121, 1
  %reg_ptr123 = getelementptr i64, ptr %regs, i64 15
  store i64 %addi122, ptr %reg_ptr123, align 4
  %reg_ptr124 = getelementptr i64, ptr %regs, i64 2
  %rv125 = load i64, ptr %reg_ptr124, align 4
  %saddr = add i64 %rv125, 24
  %reg_ptr126 = getelementptr i64, ptr %regs, i64 15
  %rv127 = load i64, ptr %reg_ptr126, align 4
  %mem_end128 = add i64 %saddr, 8
  %in_range129 = icmp ule i64 %mem_end128, %1
  br i1 %in_range129, label %mem_ok130, label %oob_trap

bb_0x101dc:                                       ; preds = %mem_ok137
  %reg_ptr153 = getelementptr i64, ptr %regs, i64 0
  %rv154 = load i64, ptr %reg_ptr153, align 4
  %addi155 = add i64 %rv154, -16
  %reg_ptr156 = getelementptr i64, ptr %regs, i64 15
  store i64 %addi155, ptr %reg_ptr156, align 4
  %reg_ptr157 = getelementptr i64, ptr %regs, i64 2
  %rv158 = load i64, ptr %reg_ptr157, align 4
  %saddr159 = add i64 %rv158, 16
  %reg_ptr160 = getelementptr i64, ptr %regs, i64 15
  %rv161 = load i64, ptr %reg_ptr160, align 4
  %mem_end162 = add i64 %saddr159, 8
  %in_range163 = icmp ule i64 %mem_end162, %1
  br i1 %in_range163, label %mem_ok164, label %oob_trap

bb_0x101f4:                                       ; preds = %mem_ok171
  %reg_ptr187 = getelementptr i64, ptr %regs, i64 0
  %rv188 = load i64, ptr %reg_ptr187, align 4
  %addi189 = add i64 %rv188, -1
  %reg_ptr190 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi189, ptr %reg_ptr190, align 4
  %reg_ptr191 = getelementptr i64, ptr %regs, i64 2
  %rv192 = load i64, ptr %reg_ptr191, align 4
  %saddr193 = add i64 %rv192, 12
  %reg_ptr194 = getelementptr i64, ptr %regs, i64 14
  %rv195 = load i64, ptr %reg_ptr194, align 4
  %mem_end196 = add i64 %saddr193, 4
  %in_range197 = icmp ule i64 %mem_end196, %1
  br i1 %in_range197, label %mem_ok198, label %oob_trap

bb_0x10208:                                       ; preds = %mem_ok205
  %reg_ptr216 = getelementptr i64, ptr %regs, i64 14
  store i64 -2147483648, ptr %reg_ptr216, align 4
  %reg_ptr217 = getelementptr i64, ptr %regs, i64 15
  store i64 -2147483648, ptr %reg_ptr217, align 4
  %reg_ptr218 = getelementptr i64, ptr %regs, i64 15
  %rv219 = load i64, ptr %reg_ptr218, align 4
  %addi220 = add i64 %rv219, -1
  %reg_ptr221 = getelementptr i64, ptr %regs, i64 15
  store i64 %addi220, ptr %reg_ptr221, align 4
  %reg_ptr222 = getelementptr i64, ptr %regs, i64 2
  %rv223 = load i64, ptr %reg_ptr222, align 4
  %saddr224 = add i64 %rv223, 8
  %reg_ptr225 = getelementptr i64, ptr %regs, i64 15
  %rv226 = load i64, ptr %reg_ptr225, align 4
  %mem_end227 = add i64 %saddr224, 4
  %in_range228 = icmp ule i64 %mem_end227, %1
  br i1 %in_range228, label %mem_ok229, label %oob_trap

bb_0x10230:                                       ; preds = %mem_ok261
  %reg_ptr275 = getelementptr i64, ptr %regs, i64 0
  %rv276 = load i64, ptr %reg_ptr275, align 4
  %addi277 = add i64 %rv276, 12
  %reg_ptr278 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi277, ptr %reg_ptr278, align 4
  %reg_ptr279 = getelementptr i64, ptr %regs, i64 1
  store i64 66104, ptr %reg_ptr279, align 4
  br label %bb_0x10144

bb_0x10238:                                       ; No predecessors!
  %reg_ptr280 = getelementptr i64, ptr %regs, i64 0
  %rv281 = load i64, ptr %reg_ptr280, align 4
  %addi282 = add i64 %rv281, 1
  %reg_ptr283 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi282, ptr %reg_ptr283, align 4
  %reg_ptr284 = getelementptr i64, ptr %regs, i64 1
  store i64 66112, ptr %reg_ptr284, align 4
  br label %bb_0x10144

bb_0x10240:                                       ; preds = %mem_ok10
  %reg_ptr285 = getelementptr i64, ptr %regs, i64 0
  %rv286 = load i64, ptr %reg_ptr285, align 4
  %addi287 = add i64 %rv286, 2
  %reg_ptr288 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi287, ptr %reg_ptr288, align 4
  %reg_ptr289 = getelementptr i64, ptr %regs, i64 1
  store i64 66120, ptr %reg_ptr289, align 4
  br label %bb_0x10144

bb_0x10248:                                       ; preds = %mem_ok36
  %reg_ptr290 = getelementptr i64, ptr %regs, i64 0
  %rv291 = load i64, ptr %reg_ptr290, align 4
  %addi292 = add i64 %rv291, 3
  %reg_ptr293 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi292, ptr %reg_ptr293, align 4
  %reg_ptr294 = getelementptr i64, ptr %regs, i64 1
  store i64 66128, ptr %reg_ptr294, align 4
  br label %bb_0x10144

bb_0x10250:                                       ; preds = %mem_ok68
  %reg_ptr295 = getelementptr i64, ptr %regs, i64 0
  %rv296 = load i64, ptr %reg_ptr295, align 4
  %addi297 = add i64 %rv296, 4
  %reg_ptr298 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi297, ptr %reg_ptr298, align 4
  %reg_ptr299 = getelementptr i64, ptr %regs, i64 1
  store i64 66136, ptr %reg_ptr299, align 4
  br label %bb_0x10144

bb_0x10258:                                       ; preds = %mem_ok101
  %reg_ptr300 = getelementptr i64, ptr %regs, i64 0
  %rv301 = load i64, ptr %reg_ptr300, align 4
  %addi302 = add i64 %rv301, 5
  %reg_ptr303 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi302, ptr %reg_ptr303, align 4
  %reg_ptr304 = getelementptr i64, ptr %regs, i64 1
  store i64 66144, ptr %reg_ptr304, align 4
  br label %bb_0x10144

bb_0x10260:                                       ; preds = %mem_ok137
  %reg_ptr305 = getelementptr i64, ptr %regs, i64 0
  %rv306 = load i64, ptr %reg_ptr305, align 4
  %addi307 = add i64 %rv306, 6
  %reg_ptr308 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi307, ptr %reg_ptr308, align 4
  %reg_ptr309 = getelementptr i64, ptr %regs, i64 1
  store i64 66152, ptr %reg_ptr309, align 4
  br label %bb_0x10144

bb_0x10268:                                       ; preds = %mem_ok171
  %reg_ptr310 = getelementptr i64, ptr %regs, i64 0
  %rv311 = load i64, ptr %reg_ptr310, align 4
  %addi312 = add i64 %rv311, 7
  %reg_ptr313 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi312, ptr %reg_ptr313, align 4
  %reg_ptr314 = getelementptr i64, ptr %regs, i64 1
  store i64 66160, ptr %reg_ptr314, align 4
  br label %bb_0x10144

bb_0x10270:                                       ; preds = %mem_ok205
  %reg_ptr315 = getelementptr i64, ptr %regs, i64 0
  %rv316 = load i64, ptr %reg_ptr315, align 4
  %addi317 = add i64 %rv316, 11
  %reg_ptr318 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi317, ptr %reg_ptr318, align 4
  %reg_ptr319 = getelementptr i64, ptr %regs, i64 1
  store i64 66168, ptr %reg_ptr319, align 4
  br label %bb_0x10144

bb_0x10278:                                       ; preds = %mem_ok261
  %reg_ptr320 = getelementptr i64, ptr %regs, i64 0
  %rv321 = load i64, ptr %reg_ptr320, align 4
  %addi322 = add i64 %rv321, 0
  %reg_ptr323 = getelementptr i64, ptr %regs, i64 10
  store i64 %addi322, ptr %reg_ptr323, align 4
  %reg_ptr324 = getelementptr i64, ptr %regs, i64 1
  store i64 66176, ptr %reg_ptr324, align 4
  br label %bb_0x10144

bb_0x10280:                                       ; No predecessors!
  unreachable

oob_trap:                                         ; preds = %mem_ok251, %mem_ok243, %mem_ok229, %bb_0x10208, %mem_ok198, %bb_0x101f4, %mem_ok164, %bb_0x101dc, %mem_ok130, %bb_0x101c4, %mem_ok92, %bb_0x101b0, %mem_ok59, %bb_0x1019c, %mem_ok27, %bb_0x10188, %mem_ok, %bb_0x10178
  ret i32 1

ecall_exit:                                       ; preds = %bb_0x10144
  ret i32 %ecall_ret

ecall_cont:                                       ; preds = %bb_0x10144
  br label %bb_0x1014c

mem_ok:                                           ; preds = %bb_0x10178
  %mem_ptr = getelementptr i8, ptr %0, i64 %laddr
  %ld = load i64, ptr %mem_ptr, align 4
  %reg_ptr4 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld, ptr %reg_ptr4, align 4
  %reg_ptr5 = getelementptr i64, ptr %regs, i64 2
  %rv6 = load i64, ptr %reg_ptr5, align 4
  %laddr7 = add i64 %rv6, 32
  %mem_end8 = add i64 %laddr7, 8
  %in_range9 = icmp ule i64 %mem_end8, %1
  br i1 %in_range9, label %mem_ok10, label %oob_trap

mem_ok10:                                         ; preds = %mem_ok
  %mem_ptr11 = getelementptr i8, ptr %0, i64 %laddr7
  %ld12 = load i64, ptr %mem_ptr11, align 4
  %reg_ptr13 = getelementptr i64, ptr %regs, i64 14
  store i64 %ld12, ptr %reg_ptr13, align 4
  %reg_ptr14 = getelementptr i64, ptr %regs, i64 15
  %rv15 = load i64, ptr %reg_ptr14, align 4
  %addi16 = add i64 %rv15, -4
  %reg_ptr17 = getelementptr i64, ptr %regs, i64 15
  store i64 %addi16, ptr %reg_ptr17, align 4
  %reg_ptr18 = getelementptr i64, ptr %regs, i64 15
  %rv19 = load i64, ptr %reg_ptr18, align 4
  %reg_ptr20 = getelementptr i64, ptr %regs, i64 14
  %rv21 = load i64, ptr %reg_ptr20, align 4
  %bne = icmp ne i64 %rv19, %rv21
  br i1 %bne, label %bb_0x10240, label %bb_0x10188

mem_ok27:                                         ; preds = %bb_0x10188
  %mem_ptr28 = getelementptr i8, ptr %0, i64 %laddr24
  %ld29 = load i64, ptr %mem_ptr28, align 4
  %reg_ptr30 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld29, ptr %reg_ptr30, align 4
  %reg_ptr31 = getelementptr i64, ptr %regs, i64 2
  %rv32 = load i64, ptr %reg_ptr31, align 4
  %laddr33 = add i64 %rv32, 32
  %mem_end34 = add i64 %laddr33, 8
  %in_range35 = icmp ule i64 %mem_end34, %1
  br i1 %in_range35, label %mem_ok36, label %oob_trap

mem_ok36:                                         ; preds = %mem_ok27
  %mem_ptr37 = getelementptr i8, ptr %0, i64 %laddr33
  %ld38 = load i64, ptr %mem_ptr37, align 4
  %reg_ptr39 = getelementptr i64, ptr %regs, i64 14
  store i64 %ld38, ptr %reg_ptr39, align 4
  %reg_ptr40 = getelementptr i64, ptr %regs, i64 15
  %rv41 = load i64, ptr %reg_ptr40, align 4
  %reg_ptr42 = getelementptr i64, ptr %regs, i64 14
  %rv43 = load i64, ptr %reg_ptr42, align 4
  %sh6 = and i64 %rv43, 63
  %and = and i64 %rv41, %rv43
  %reg_ptr44 = getelementptr i64, ptr %regs, i64 15
  store i64 %and, ptr %reg_ptr44, align 4
  %reg_ptr45 = getelementptr i64, ptr %regs, i64 0
  %rv46 = load i64, ptr %reg_ptr45, align 4
  %addi47 = add i64 %rv46, 3
  %reg_ptr48 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi47, ptr %reg_ptr48, align 4
  %reg_ptr49 = getelementptr i64, ptr %regs, i64 15
  %rv50 = load i64, ptr %reg_ptr49, align 4
  %reg_ptr51 = getelementptr i64, ptr %regs, i64 14
  %rv52 = load i64, ptr %reg_ptr51, align 4
  %bne53 = icmp ne i64 %rv50, %rv52
  br i1 %bne53, label %bb_0x10248, label %bb_0x1019c

mem_ok59:                                         ; preds = %bb_0x1019c
  %mem_ptr60 = getelementptr i8, ptr %0, i64 %laddr56
  %ld61 = load i64, ptr %mem_ptr60, align 4
  %reg_ptr62 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld61, ptr %reg_ptr62, align 4
  %reg_ptr63 = getelementptr i64, ptr %regs, i64 2
  %rv64 = load i64, ptr %reg_ptr63, align 4
  %laddr65 = add i64 %rv64, 32
  %mem_end66 = add i64 %laddr65, 8
  %in_range67 = icmp ule i64 %mem_end66, %1
  br i1 %in_range67, label %mem_ok68, label %oob_trap

mem_ok68:                                         ; preds = %mem_ok59
  %mem_ptr69 = getelementptr i8, ptr %0, i64 %laddr65
  %ld70 = load i64, ptr %mem_ptr69, align 4
  %reg_ptr71 = getelementptr i64, ptr %regs, i64 14
  store i64 %ld70, ptr %reg_ptr71, align 4
  %reg_ptr72 = getelementptr i64, ptr %regs, i64 15
  %rv73 = load i64, ptr %reg_ptr72, align 4
  %reg_ptr74 = getelementptr i64, ptr %regs, i64 14
  %rv75 = load i64, ptr %reg_ptr74, align 4
  %sh676 = and i64 %rv75, 63
  %or = or i64 %rv73, %rv75
  %reg_ptr77 = getelementptr i64, ptr %regs, i64 15
  store i64 %or, ptr %reg_ptr77, align 4
  %reg_ptr78 = getelementptr i64, ptr %regs, i64 0
  %rv79 = load i64, ptr %reg_ptr78, align 4
  %addi80 = add i64 %rv79, 7
  %reg_ptr81 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi80, ptr %reg_ptr81, align 4
  %reg_ptr82 = getelementptr i64, ptr %regs, i64 15
  %rv83 = load i64, ptr %reg_ptr82, align 4
  %reg_ptr84 = getelementptr i64, ptr %regs, i64 14
  %rv85 = load i64, ptr %reg_ptr84, align 4
  %bne86 = icmp ne i64 %rv83, %rv85
  br i1 %bne86, label %bb_0x10250, label %bb_0x101b0

mem_ok92:                                         ; preds = %bb_0x101b0
  %mem_ptr93 = getelementptr i8, ptr %0, i64 %laddr89
  %ld94 = load i64, ptr %mem_ptr93, align 4
  %reg_ptr95 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld94, ptr %reg_ptr95, align 4
  %reg_ptr96 = getelementptr i64, ptr %regs, i64 2
  %rv97 = load i64, ptr %reg_ptr96, align 4
  %laddr98 = add i64 %rv97, 32
  %mem_end99 = add i64 %laddr98, 8
  %in_range100 = icmp ule i64 %mem_end99, %1
  br i1 %in_range100, label %mem_ok101, label %oob_trap

mem_ok101:                                        ; preds = %mem_ok92
  %mem_ptr102 = getelementptr i8, ptr %0, i64 %laddr98
  %ld103 = load i64, ptr %mem_ptr102, align 4
  %reg_ptr104 = getelementptr i64, ptr %regs, i64 14
  store i64 %ld103, ptr %reg_ptr104, align 4
  %reg_ptr105 = getelementptr i64, ptr %regs, i64 15
  %rv106 = load i64, ptr %reg_ptr105, align 4
  %reg_ptr107 = getelementptr i64, ptr %regs, i64 14
  %rv108 = load i64, ptr %reg_ptr107, align 4
  %sh6109 = and i64 %rv108, 63
  %xor = xor i64 %rv106, %rv108
  %reg_ptr110 = getelementptr i64, ptr %regs, i64 15
  store i64 %xor, ptr %reg_ptr110, align 4
  %reg_ptr111 = getelementptr i64, ptr %regs, i64 0
  %rv112 = load i64, ptr %reg_ptr111, align 4
  %addi113 = add i64 %rv112, 4
  %reg_ptr114 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi113, ptr %reg_ptr114, align 4
  %reg_ptr115 = getelementptr i64, ptr %regs, i64 15
  %rv116 = load i64, ptr %reg_ptr115, align 4
  %reg_ptr117 = getelementptr i64, ptr %regs, i64 14
  %rv118 = load i64, ptr %reg_ptr117, align 4
  %bne119 = icmp ne i64 %rv116, %rv118
  br i1 %bne119, label %bb_0x10258, label %bb_0x101c4

mem_ok130:                                        ; preds = %bb_0x101c4
  %mem_ptr131 = getelementptr i8, ptr %0, i64 %saddr
  store i64 %rv127, ptr %mem_ptr131, align 4
  %reg_ptr132 = getelementptr i64, ptr %regs, i64 2
  %rv133 = load i64, ptr %reg_ptr132, align 4
  %laddr134 = add i64 %rv133, 24
  %mem_end135 = add i64 %laddr134, 8
  %in_range136 = icmp ule i64 %mem_end135, %1
  br i1 %in_range136, label %mem_ok137, label %oob_trap

mem_ok137:                                        ; preds = %mem_ok130
  %mem_ptr138 = getelementptr i8, ptr %0, i64 %laddr134
  %ld139 = load i64, ptr %mem_ptr138, align 4
  %reg_ptr140 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld139, ptr %reg_ptr140, align 4
  %reg_ptr141 = getelementptr i64, ptr %regs, i64 15
  %rv142 = load i64, ptr %reg_ptr141, align 4
  %slli = shl i64 %rv142, 4
  %reg_ptr143 = getelementptr i64, ptr %regs, i64 15
  store i64 %slli, ptr %reg_ptr143, align 4
  %reg_ptr144 = getelementptr i64, ptr %regs, i64 0
  %rv145 = load i64, ptr %reg_ptr144, align 4
  %addi146 = add i64 %rv145, 16
  %reg_ptr147 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi146, ptr %reg_ptr147, align 4
  %reg_ptr148 = getelementptr i64, ptr %regs, i64 15
  %rv149 = load i64, ptr %reg_ptr148, align 4
  %reg_ptr150 = getelementptr i64, ptr %regs, i64 14
  %rv151 = load i64, ptr %reg_ptr150, align 4
  %bne152 = icmp ne i64 %rv149, %rv151
  br i1 %bne152, label %bb_0x10260, label %bb_0x101dc

mem_ok164:                                        ; preds = %bb_0x101dc
  %mem_ptr165 = getelementptr i8, ptr %0, i64 %saddr159
  store i64 %rv161, ptr %mem_ptr165, align 4
  %reg_ptr166 = getelementptr i64, ptr %regs, i64 2
  %rv167 = load i64, ptr %reg_ptr166, align 4
  %laddr168 = add i64 %rv167, 16
  %mem_end169 = add i64 %laddr168, 8
  %in_range170 = icmp ule i64 %mem_end169, %1
  br i1 %in_range170, label %mem_ok171, label %oob_trap

mem_ok171:                                        ; preds = %mem_ok164
  %mem_ptr172 = getelementptr i8, ptr %0, i64 %laddr168
  %ld173 = load i64, ptr %mem_ptr172, align 4
  %reg_ptr174 = getelementptr i64, ptr %regs, i64 15
  store i64 %ld173, ptr %reg_ptr174, align 4
  %reg_ptr175 = getelementptr i64, ptr %regs, i64 15
  %rv176 = load i64, ptr %reg_ptr175, align 4
  %srai = ashr i64 %rv176, 2
  %reg_ptr177 = getelementptr i64, ptr %regs, i64 15
  store i64 %srai, ptr %reg_ptr177, align 4
  %reg_ptr178 = getelementptr i64, ptr %regs, i64 0
  %rv179 = load i64, ptr %reg_ptr178, align 4
  %addi180 = add i64 %rv179, -4
  %reg_ptr181 = getelementptr i64, ptr %regs, i64 14
  store i64 %addi180, ptr %reg_ptr181, align 4
  %reg_ptr182 = getelementptr i64, ptr %regs, i64 15
  %rv183 = load i64, ptr %reg_ptr182, align 4
  %reg_ptr184 = getelementptr i64, ptr %regs, i64 14
  %rv185 = load i64, ptr %reg_ptr184, align 4
  %bne186 = icmp ne i64 %rv183, %rv185
  br i1 %bne186, label %bb_0x10268, label %bb_0x101f4

mem_ok198:                                        ; preds = %bb_0x101f4
  %mem_ptr199 = getelementptr i8, ptr %0, i64 %saddr193
  %sv32 = trunc i64 %rv195 to i32
  store i32 %sv32, ptr %mem_ptr199, align 4
  %reg_ptr200 = getelementptr i64, ptr %regs, i64 2
  %rv201 = load i64, ptr %reg_ptr200, align 4
  %laddr202 = add i64 %rv201, 12
  %mem_end203 = add i64 %laddr202, 4
  %in_range204 = icmp ule i64 %mem_end203, %1
  br i1 %in_range204, label %mem_ok205, label %oob_trap

mem_ok205:                                        ; preds = %mem_ok198
  %mem_ptr206 = getelementptr i8, ptr %0, i64 %laddr202
  %lv32 = load i32, ptr %mem_ptr206, align 4
  %lw = sext i32 %lv32 to i64
  %reg_ptr207 = getelementptr i64, ptr %regs, i64 15
  store i64 %lw, ptr %reg_ptr207, align 4
  %reg_ptr208 = getelementptr i64, ptr %regs, i64 15
  %rv209 = load i64, ptr %reg_ptr208, align 4
  %src32 = trunc i64 %rv209 to i32
  %addiw = add i32 %src32, 0
  %addiw_sx = sext i32 %addiw to i64
  %reg_ptr210 = getelementptr i64, ptr %regs, i64 15
  store i64 %addiw_sx, ptr %reg_ptr210, align 4
  %reg_ptr211 = getelementptr i64, ptr %regs, i64 15
  %rv212 = load i64, ptr %reg_ptr211, align 4
  %reg_ptr213 = getelementptr i64, ptr %regs, i64 14
  %rv214 = load i64, ptr %reg_ptr213, align 4
  %bne215 = icmp ne i64 %rv212, %rv214
  br i1 %bne215, label %bb_0x10270, label %bb_0x10208

mem_ok229:                                        ; preds = %bb_0x10208
  %mem_ptr230 = getelementptr i8, ptr %0, i64 %saddr224
  %sv32231 = trunc i64 %rv226 to i32
  store i32 %sv32231, ptr %mem_ptr230, align 4
  %reg_ptr232 = getelementptr i64, ptr %regs, i64 0
  %rv233 = load i64, ptr %reg_ptr232, align 4
  %addi234 = add i64 %rv233, 1
  %reg_ptr235 = getelementptr i64, ptr %regs, i64 15
  store i64 %addi234, ptr %reg_ptr235, align 4
  %reg_ptr236 = getelementptr i64, ptr %regs, i64 2
  %rv237 = load i64, ptr %reg_ptr236, align 4
  %saddr238 = add i64 %rv237, 4
  %reg_ptr239 = getelementptr i64, ptr %regs, i64 15
  %rv240 = load i64, ptr %reg_ptr239, align 4
  %mem_end241 = add i64 %saddr238, 4
  %in_range242 = icmp ule i64 %mem_end241, %1
  br i1 %in_range242, label %mem_ok243, label %oob_trap

mem_ok243:                                        ; preds = %mem_ok229
  %mem_ptr244 = getelementptr i8, ptr %0, i64 %saddr238
  %sv32245 = trunc i64 %rv240 to i32
  store i32 %sv32245, ptr %mem_ptr244, align 4
  %reg_ptr246 = getelementptr i64, ptr %regs, i64 2
  %rv247 = load i64, ptr %reg_ptr246, align 4
  %laddr248 = add i64 %rv247, 8
  %mem_end249 = add i64 %laddr248, 4
  %in_range250 = icmp ule i64 %mem_end249, %1
  br i1 %in_range250, label %mem_ok251, label %oob_trap

mem_ok251:                                        ; preds = %mem_ok243
  %mem_ptr252 = getelementptr i8, ptr %0, i64 %laddr248
  %lv32253 = load i32, ptr %mem_ptr252, align 4
  %lw254 = sext i32 %lv32253 to i64
  %reg_ptr255 = getelementptr i64, ptr %regs, i64 15
  store i64 %lw254, ptr %reg_ptr255, align 4
  %reg_ptr256 = getelementptr i64, ptr %regs, i64 2
  %rv257 = load i64, ptr %reg_ptr256, align 4
  %laddr258 = add i64 %rv257, 4
  %mem_end259 = add i64 %laddr258, 4
  %in_range260 = icmp ule i64 %mem_end259, %1
  br i1 %in_range260, label %mem_ok261, label %oob_trap

mem_ok261:                                        ; preds = %mem_ok251
  %mem_ptr262 = getelementptr i8, ptr %0, i64 %laddr258
  %lv32263 = load i32, ptr %mem_ptr262, align 4
  %lw264 = sext i32 %lv32263 to i64
  %reg_ptr265 = getelementptr i64, ptr %regs, i64 13
  store i64 %lw264, ptr %reg_ptr265, align 4
  %reg_ptr266 = getelementptr i64, ptr %regs, i64 15
  %rv267 = load i64, ptr %reg_ptr266, align 4
  %v1_32 = trunc i64 %rv267 to i32
  %reg_ptr268 = getelementptr i64, ptr %regs, i64 13
  %rv269 = load i64, ptr %reg_ptr268, align 4
  %v2_32 = trunc i64 %rv269 to i32
  %sh5 = and i32 %v2_32, 31
  %addw = add i32 %v1_32, %v2_32
  %op32_sx = sext i32 %addw to i64
  %reg_ptr270 = getelementptr i64, ptr %regs, i64 15
  store i64 %op32_sx, ptr %reg_ptr270, align 4
  %reg_ptr271 = getelementptr i64, ptr %regs, i64 15
  %rv272 = load i64, ptr %reg_ptr271, align 4
  %reg_ptr273 = getelementptr i64, ptr %regs, i64 14
  %rv274 = load i64, ptr %reg_ptr273, align 4
  %beq = icmp eq i64 %rv272, %rv274
  br i1 %beq, label %bb_0x10278, label %bb_0x10230
}

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #0

attributes #0 = { nocallback nofree nounwind willreturn memory(argmem: write) }
