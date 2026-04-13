    # RV64I arithmetic test — hand-written assembly.
    #
    # All operands are spilled to the stack before each operation so that the
    # JIT's LLVM IR sees GEP+load instructions rather than known constants, which
    # prevents the optimiser from trivially constant-folding the whole test to
    # a single "exit(0)".
    #
    # Tests (same cases as tests/arith.c):
    #   1  add      7 + 3 == 10
    #   2  sub      7 - 3 ==  4
    #   3  and      7 & 3 ==  3
    #   4  or       7 | 3 ==  7
    #   5  xor      7 ^ 3 ==  4
    #   6  sll      1 << 4 == 16
    #   7  sra     -16 >> 2 == -4  (arithmetic)
    #   8  slt      3 <s 7  ==  1
    #   9  slt      7 <s 3  ==  0
    #  10  sltu     3 <u 7  ==  1
    #  11  lw sign-extension: *(int32 *)-1  sign-extended to 64-bit == -1
    #  12  addw wrap: 0x7FFFFFFF + 1 == -2147483648 (32-bit overflow, sign-extended)
    #
    # Returns exit code 0 on success, or the failing test number on error.

    .section .text
    .global _start

# ---------------------------------------------------------------------------
# do_exit(code)  –  a0 = exit code; does not return.
# ---------------------------------------------------------------------------
do_exit:
    li      a7, 93          # sys_exit
    ecall

# ---------------------------------------------------------------------------
# _start
# ---------------------------------------------------------------------------
_start:
    addi    sp, sp, -64     # 64-byte frame
    sd      ra, 56(sp)

    # Spill the two primary operands (a=7, b=3) once; reload before each test.
    li      t0, 7
    li      t1, 3
    sd      t0,  0(sp)      # [sp+0]  = a = 7
    sd      t1,  8(sp)      # [sp+8]  = b = 3

    # ------------------------------------------------------------------
    # Test 1: add   a + b == 10
    # ------------------------------------------------------------------
    ld      t0,  0(sp)
    ld      t1,  8(sp)
    add     t2, t0, t1
    li      t3, 10
    bne     t2, t3, .Lfail1

    # ------------------------------------------------------------------
    # Test 2: sub   a - b == 4
    # ------------------------------------------------------------------
    ld      t0,  0(sp)
    ld      t1,  8(sp)
    sub     t2, t0, t1
    li      t3, 4
    bne     t2, t3, .Lfail2

    # ------------------------------------------------------------------
    # Test 3: and   a & b == 3
    # ------------------------------------------------------------------
    ld      t0,  0(sp)
    ld      t1,  8(sp)
    and     t2, t0, t1
    li      t3, 3
    bne     t2, t3, .Lfail3

    # ------------------------------------------------------------------
    # Test 4: or    a | b == 7
    # ------------------------------------------------------------------
    ld      t0,  0(sp)
    ld      t1,  8(sp)
    or      t2, t0, t1
    li      t3, 7
    bne     t2, t3, .Lfail4

    # ------------------------------------------------------------------
    # Test 5: xor   a ^ b == 4
    # ------------------------------------------------------------------
    ld      t0,  0(sp)
    ld      t1,  8(sp)
    xor     t2, t0, t1
    li      t3, 4
    bne     t2, t3, .Lfail5

    # ------------------------------------------------------------------
    # Test 6: sll   c << shift == 16
    # ------------------------------------------------------------------
    li      t0, 1
    li      t1, 4
    sd      t0, 16(sp)      # [sp+16] = c     = 1
    sd      t1, 24(sp)      # [sp+24] = shift = 4
    ld      t0, 16(sp)
    ld      t1, 24(sp)
    sll     t2, t0, t1
    li      t3, 16
    bne     t2, t3, .Lfail6

    # ------------------------------------------------------------------
    # Test 7: sra   d >> 2 == -4  (arithmetic right-shift)
    # ------------------------------------------------------------------
    li      t0, -16
    li      t1, 2
    sd      t0, 32(sp)      # [sp+32] = d = -16
    sd      t1, 40(sp)      # [sp+40] = 2
    ld      t0, 32(sp)
    ld      t1, 40(sp)
    sra     t2, t0, t1
    li      t3, -4
    bne     t2, t3, .Lfail7

    # ------------------------------------------------------------------
    # Test 8: slt (signed)   3 <s 7  == 1
    # ------------------------------------------------------------------
    ld      t0,  8(sp)      # b = 3
    ld      t1,  0(sp)      # a = 7
    slt     t2, t0, t1      # 3 <s 7  → 1
    li      t3, 1
    bne     t2, t3, .Lfail8

    # ------------------------------------------------------------------
    # Test 9: slt (signed)   7 <s 3  == 0
    # ------------------------------------------------------------------
    ld      t0,  0(sp)      # a = 7
    ld      t1,  8(sp)      # b = 3
    slt     t2, t0, t1      # 7 <s 3  → 0
    li      t3, 0
    bne     t2, t3, .Lfail9

    # ------------------------------------------------------------------
    # Test 10: sltu (unsigned)  3 <u 7  == 1
    # ------------------------------------------------------------------
    ld      t0,  8(sp)      # 3
    ld      t1,  0(sp)      # 7
    sltu    t2, t0, t1      # 3 <u 7  → 1
    li      t3, 1
    bne     t2, t3, .Lfail10

    # ------------------------------------------------------------------
    # Test 11: lw sign-extension  — store word -1, reload as sign-extended 64-bit
    # ------------------------------------------------------------------
    li      t0, -1
    sw      t0, 48(sp)      # write 32-bit all-ones
    lw      t1, 48(sp)      # load sign-extended → 64-bit -1
    li      t2, -1
    bne     t1, t2, .Lfail11

    # ------------------------------------------------------------------
    # Test 12: addw wraps  0x7FFFFFFF + 1 == -2147483648 (sign-extended)
    # ------------------------------------------------------------------
    li      t0, 0x7FFFFFFF
    li      t1, 1
    sw      t0, 48(sp)
    sw      t1, 52(sp)
    lw      t0, 48(sp)
    lw      t1, 52(sp)
    addw    t2, t0, t1      # 32-bit add wraps, sign-extended to 64-bit
    li      t3, -2147483648
    bne     t2, t3, .Lfail12

    # ------------------------------------------------------------------
    # All tests passed
    # ------------------------------------------------------------------
    ld      ra, 56(sp)
    addi    sp, sp, 64
    li      a0, 0
    jal     ra, do_exit

.Lfail1:  li a0,  1;  jal ra, do_exit
.Lfail2:  li a0,  2;  jal ra, do_exit
.Lfail3:  li a0,  3;  jal ra, do_exit
.Lfail4:  li a0,  4;  jal ra, do_exit
.Lfail5:  li a0,  5;  jal ra, do_exit
.Lfail6:  li a0,  6;  jal ra, do_exit
.Lfail7:  li a0,  7;  jal ra, do_exit
.Lfail8:  li a0,  8;  jal ra, do_exit
.Lfail9:  li a0,  9;  jal ra, do_exit
.Lfail10: li a0, 10;  jal ra, do_exit
.Lfail11: li a0, 11;  jal ra, do_exit
.Lfail12: li a0, 12;  jal ra, do_exit
