    .section .data
msg:
    .ascii  "Hello, world!\n"
msg_len = . - msg

    .section .text
    .global _start
_start:
    li      a7, 64          # sys_write
    li      a0, 1           # fd: stdout
    la      a1, msg         # buf
    li      a2, msg_len     # len = 14
    ecall

    li      a7, 93          # sys_exit
    li      a0, 0           # status: 0
    ecall
