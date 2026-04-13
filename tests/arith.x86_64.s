	.text
	.file	"riscv_jit"
	.globl	jit_main
	.p2align	4, 0x90
	.type	jit_main,@function
jit_main:
	.cfi_startproc
	pushq	%r15
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	subq	$256, %rsp
	.cfi_def_cfa_offset 288
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %r15, -16
	movq	%rsi, %rbx
	movq	%rdi, %r14
	vxorps	%xmm0, %xmm0, %xmm0
	vmovups	%zmm0, (%rsp)
	vmovups	%zmm0, 192(%rsp)
	vmovups	%zmm0, 128(%rsp)
	vmovups	%zmm0, 64(%rsp)
	movq	%rdx, 16(%rsp)
	movq	%rsp, %r15
	.p2align	4, 0x90
.LBB0_1:
	movq	(%rsp), %rax
	addq	$93, %rax
	movq	%rax, 136(%rsp)
	movq	%r15, %rdi
	movq	%r14, %rsi
	movq	%rbx, %rdx
	vzeroupper
	callq	jit_ecall@PLT
	testl	%eax, %eax
	js	.LBB0_1
	addq	$256, %rsp
	.cfi_def_cfa_offset 32
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%r15
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end0:
	.size	jit_main, .Lfunc_end0-jit_main
	.cfi_endproc

	.section	".note.GNU-stack","",@progbits
