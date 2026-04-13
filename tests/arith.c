/*
 * Arithmetic validation program for the RV64I emulator.
 *
 * Tests base-integer operations (no M-extension: no mul/div/rem).
 * Returns exit code 0 on success, or the number of the failing test otherwise.
 *
 * Compile with:
 *   riscv64-linux-gnu-gcc -static -march=rv64i -mabi=lp64 \
 *                         -nostdlib -O1 -o tests/arith tests/arith.c
 *
 * Verify with QEMU:
 *   qemu-riscv64 tests/arith; echo "exit: $?"   # should print 0
 */

static void do_exit(int code) {
    register long a7 __asm__("a7") = 93;
    register long a0 __asm__("a0") = code;
    __asm__ volatile("ecall" :: "r"(a0), "r"(a7) : "memory");
    __builtin_unreachable();
}

void _start(void) {
    volatile long a = 7, b = 3;

    if (a + b   != 10)  do_exit(1);   /* add */
    if (a - b   !=  4)  do_exit(2);   /* sub */
    if ((a & b) !=  3)  do_exit(3);   /* and */
    if ((a | b) !=  7)  do_exit(4);   /* or  */
    if ((a ^ b) !=  4)  do_exit(5);   /* xor */

    volatile long c = 1L;
    if ((c << 4) != 16) do_exit(6);   /* sll */

    volatile long d = -16L;
    if ((d >> 2) != -4) do_exit(7);   /* sra */

    if (!((long)3 < (long)7))  do_exit(8);  /* slt  (true) */
    if ( ((long)7 < (long)3))  do_exit(9);  /* slt  (false) */
    if (!((unsigned long)3 < (unsigned long)7))  do_exit(10); /* sltu (true) */

    /* 32-bit word ops (sign-extended) */
    volatile int w = -1;
    if ((long)w != -1L) do_exit(11);  /* sign extension of 32-bit -1 */

    volatile int wa = 0x7FFFFFFF;
    volatile int wb = 1;
    int wsum = wa + wb;               /* should wrap to -2147483648 */
    if ((long)wsum != -2147483648L) do_exit(12);

    do_exit(0);
}
