    # RV64I call / return test — hand-written assembly.
    #
    # All arguments are spilled to the stack and reloaded before each call so
    # the JIT's LLVM IR sees GEP+load rather than constants, preventing the
    # optimiser from constant-folding the calls away.
    #
    # Functions under test:
    #   sum3(a0, a1, a2) -> a0        leaf: returns a0+a1+a2
    #   double_sum3(a0, a1, a2) -> a0 non-leaf: calls sum3 twice, returns 2*(a0+a1+a2)
    #
    # Tests:
    #   1  leaf call: sum3(2, 3, 5) == 10
    #   2  non-leaf:  double_sum3(2, 3, 5) == 20
    #   3  chained:   sum3( sum3(1,2,3), 4, 0 ) == 10   (return value flows into next call)
    #
    # Returns exit code 0 on success, or the failing test number on error.

    .section .text
    .global _start

# ---------------------------------------------------------------------------
# do_exit(a0 = exit code)  — does not return
# ---------------------------------------------------------------------------
do_exit:
    li      a7, 93
    ecall

# ---------------------------------------------------------------------------
# sum3(a0, a1, a2) -> a0 = a0+a1+a2    (leaf function)
# ---------------------------------------------------------------------------
sum3:
    add     a0, a0, a1
    add     a0, a0, a2
    ret

# ---------------------------------------------------------------------------
# double_sum3(a0, a1, a2) -> a0 = 2*(a0+a1+a2)   (non-leaf, calls sum3 twice)
#
# sum3 is a leaf that only writes a0, so a1 and a2 survive across the call.
# We save ra and the original a0 (clobbered by the first return value) so we
# can make a second call with identical arguments.
# ---------------------------------------------------------------------------
double_sum3:
    addi    sp, sp, -16
    sd      ra,  0(sp)
    sd      a0,  8(sp)          # save original a0

    jal     ra, sum3             # a0 = a0+a1+a2  (first call; a1,a2 preserved)
    mv      t0, a0               # t0 = first result

    ld      a0,  8(sp)          # restore original a0 for second call
    jal     ra, sum3             # a0 = a0+a1+a2  (second call; same args)

    add     a0, a0, t0           # a0 = first + second = 2*(a0+a1+a2)
    ld      ra,  0(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# _start
# ---------------------------------------------------------------------------
_start:
    addi    sp, sp, -48
    sd      ra, 40(sp)

    # Spill test arguments so LLVM cannot see them as constants.
    li      t0, 2
    li      t1, 3
    li      t2, 5
    sd      t0,  0(sp)           # [sp+ 0] = 2
    sd      t1,  8(sp)           # [sp+ 8] = 3
    sd      t2, 16(sp)           # [sp+16] = 5

    # ------------------------------------------------------------------
    # Test 1: sum3(2, 3, 5) == 10   (leaf call)
    # ------------------------------------------------------------------
    ld      a0,  0(sp)
    ld      a1,  8(sp)
    ld      a2, 16(sp)
    jal     ra, sum3
    li      t0, 10
    bne     a0, t0, .Lfail1

    # ------------------------------------------------------------------
    # Test 2: double_sum3(2, 3, 5) == 20   (non-leaf, two nested calls)
    # ------------------------------------------------------------------
    ld      a0,  0(sp)
    ld      a1,  8(sp)
    ld      a2, 16(sp)
    jal     ra, double_sum3
    li      t0, 20
    bne     a0, t0, .Lfail2

    # ------------------------------------------------------------------
    # Test 3: sum3(sum3(1,2,3), 4, 0) == 10   (chained calls)
    #
    # Inner: sum3(1,2,3) == 6; outer: sum3(6,4,0) == 10.
    # ------------------------------------------------------------------
    li      t0, 1
    li      t1, 2
    li      t2, 3
    li      t3, 4
    sd      t0, 24(sp)           # [sp+24] = 1
    sd      t1, 32(sp)           # [sp+32] = 2
    sd      t2, 16(sp)           # reuse [sp+16] = 3
    sd      t3,  8(sp)           # reuse [sp+ 8] = 4  (outer a1)

    ld      a0, 24(sp)           # inner: a0=1
    ld      a1, 32(sp)           # inner: a1=2
    ld      a2, 16(sp)           # inner: a2=3
    jal     ra, sum3             # a0 = 6

    mv      a0, a0               # outer a0 = 6 (inner result)
    ld      a1,  8(sp)           # outer a1 = 4
    li      a2, 0                # outer a2 = 0
    jal     ra, sum3             # a0 = 10

    li      t0, 10
    bne     a0, t0, .Lfail3

    # ------------------------------------------------------------------
    # All tests passed
    # ------------------------------------------------------------------
    ld      ra, 40(sp)
    addi    sp, sp, 48
    li      a0, 0
    jal     ra, do_exit

.Lfail1:  li a0, 1; jal ra, do_exit
.Lfail2:  li a0, 2; jal ra, do_exit
.Lfail3:  li a0, 3; jal ra, do_exit
