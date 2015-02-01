// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "zasm_GOOS_GOARCH.h"
#include "funcdata.h"
#include "textflag.h"

TEXT runtime·rt0_go(SB),NOSPLIT,$0
	// copy arguments forward on an even stack
	MOVQ	DI, AX		// argc
	MOVQ	SI, BX		// argv
	SUBQ	$(4*8+7), SP		// 2args 2auto
	ANDQ	$~15, SP
	MOVQ	AX, 16(SP)
	MOVQ	BX, 24(SP)
	
	// create istack out of the given (operating system) stack.
	// _cgo_init may update stackguard.
	MOVQ	$runtime·g0(SB), DI
	LEAQ	(-64*1024+104)(SP), BX
	MOVQ	BX, g_stackguard0(DI)
	MOVQ	BX, g_stackguard1(DI)
	MOVQ	BX, (g_stack+stack_lo)(DI)
	MOVQ	SP, (g_stack+stack_hi)(DI)

	// find out information about the processor we're on
	MOVQ	$0, AX
	CPUID
	CMPQ	AX, $0
	JE	nocpuinfo
	MOVQ	$1, AX
	CPUID
	MOVL	CX, runtime·cpuid_ecx(SB)
	MOVL	DX, runtime·cpuid_edx(SB)
nocpuinfo:	
	
	// if there is an _cgo_init, call it.
	MOVQ	_cgo_init(SB), AX
	TESTQ	AX, AX
	JZ	needtls
	// g0 already in DI
	MOVQ	DI, CX	// Win64 uses CX for first parameter
	MOVQ	$setg_gcc<>(SB), SI
	CALL	AX

	// update stackguard after _cgo_init
	MOVQ	$runtime·g0(SB), CX
	MOVQ	(g_stack+stack_lo)(CX), AX
	ADDQ	$const_StackGuard, AX
	MOVQ	AX, g_stackguard0(CX)
	MOVQ	AX, g_stackguard1(CX)

	CMPL	runtime·iswindows(SB), $0
	JEQ ok
needtls:
	// skip TLS setup on Plan 9
	CMPL	runtime·isplan9(SB), $1
	JEQ ok
	// skip TLS setup on Solaris
	CMPL	runtime·issolaris(SB), $1
	JEQ ok

	LEAQ	runtime·tls0(SB), DI
	CALL	runtime·settls(SB)

	// store through it, to make sure it works
	get_tls(BX)
	MOVQ	$0x123, g(BX)
	MOVQ	runtime·tls0(SB), AX
	CMPQ	AX, $0x123
	JEQ 2(PC)
	MOVL	AX, 0	// abort
ok:
	// set the per-goroutine and per-mach "registers"
	get_tls(BX)
	LEAQ	runtime·g0(SB), CX
	MOVQ	CX, g(BX)
	LEAQ	runtime·m0(SB), AX

	// save m->g0 = g0
	MOVQ	CX, m_g0(AX)
	// save m0 to g0->m
	MOVQ	AX, g_m(CX)

	CLD				// convention is D is always left cleared
	CALL	runtime·check(SB)

	MOVL	16(SP), AX		// copy argc
	MOVL	AX, 0(SP)
	MOVQ	24(SP), AX		// copy argv
	MOVQ	AX, 8(SP)
	CALL	runtime·args(SB)
	CALL	runtime·osinit(SB)
	CALL	runtime·schedinit(SB)

	// create a new goroutine to start program
	MOVQ	$runtime·main·f(SB), BP		// entry
	PUSHQ	BP
	PUSHQ	$0			// arg size
	CALL	runtime·newproc(SB)
	POPQ	AX
	POPQ	AX

	// start this M
	CALL	runtime·mstart(SB)

	MOVL	$0xf1, 0xf1  // crash
	RET

DATA	runtime·main·f+0(SB)/8,$runtime·main(SB)
GLOBL	runtime·main·f(SB),RODATA,$8

TEXT runtime·breakpoint(SB),NOSPLIT,$0-0
	BYTE	$0xcc
	RET

TEXT runtime·asminit(SB),NOSPLIT,$0-0
	// No per-thread init.
	RET

#define		CODESEG		1
#define		DATASEG		2
#define		FSSEG		3

TEXT fixcs(SB),NOSPLIT,$0
	POPQ	AX
	PUSHQ	$(CODESEG << 3)
	PUSHQ	AX
	// lretq
	BYTE	$0x48
	BYTE	$0xcb
	MOVQ	$1, 0
	//POPQ	DX
	//MOVQ	$(3 << 3), AX
	//SHLQ	$32, AX
	//ORQ	DX, AX
	//PUSHQ	AX
	//// lret
	//BYTE	$0xcb
	//MOVQ	$1, 0

TEXT runtime·deray(SB),NOSPLIT,$8
	MOVQ	times+0(FP), CX
back:
	// inb	$0x80, %al
	BYTE	$0xe4
	BYTE	$0x80
	LOOP	back
	RET

// i do it this strange way because if i declare fakeargv in C i get 'missing
// golang type information'. need two 0 entries because go checks for
// environment variables too.
DATA	fakeargv+0(SB)/8,$gostr(SB)
DATA	fakeargv+8(SB)/8,$0
DATA	fakeargv+16(SB)/8,$0
GLOBL	fakeargv(SB),RODATA,$24

TEXT runtime·rt0_go_hack(SB),NOSPLIT,$0

	// magic loop
	//BYTE	$0xeb
	//BYTE	$0xfe

	// save page table and first free address from bootloader.
	MOVL	DI, kpmap(SB)
	MOVL	SI, runtime·Pgfirst(SB)
	MOVQ	$1, runtime·hackmode(SB)

	ANDQ	$~15, SP
	//SUBQ	$8, SP	// traceback assumes the initial rsp is writable

	// create istack out of the given (operating system) stack.
	// _cgo_init may update stackguard.
	MOVQ	$runtime·g0(SB), DI
	LEAQ	(-64*1024+104)(SP), BX
	//LEAQ	(-4*1024+104)(SP), BX
	MOVQ	BX, g_stackguard0(DI)
	MOVQ	BX, g_stackguard1(DI)
	MOVQ	BX, (g_stack+stack_lo)(DI)
	MOVQ	SP, (g_stack+stack_hi)(DI)

	// find out information about the processor we're on
	MOVQ	$0, AX
	CPUID
	CMPQ	AX, $0
	JE	h_nocpuinfo
	MOVQ	$1, AX
	CPUID
	MOVL	CX, runtime·cpuid_ecx(SB)
	MOVL	DX, runtime·cpuid_edx(SB)
h_nocpuinfo:

	CALL	runtime·cls(SB)

	// if there is an _cgo_init, call it.
	//MOVQ	_cgo_init(SB), AX
	//TESTQ	AX, AX
	//JZ	needtls
	//// g0 already in DI
	//MOVQ	DI, CX	// Win64 uses CX for first parameter
	//MOVQ	$setg_gcc<>(SB), SI
	//CALL	AX

	//// update stackguard after _cgo_init
	//MOVQ	$runtime·g0(SB), CX
	//MOVQ	(g_stack+stack_lo)(CX), AX
	//ADDQ	$const_StackGuard, AX
	//MOVQ	AX, g_stackguard0(CX)
	//MOVQ	AX, g_stackguard1(CX)

	//CMPL	runtime·iswindows(SB), $0
	//JEQ ok
h_needtls:

	//// skip TLS setup on Plan 9
	//CMPL	runtime·isplan9(SB), $1
	//JEQ ok
	//// skip TLS setup on Solaris
	//CMPL	runtime·issolaris(SB), $1
	//JEQ ok

	// setup tls
	LEAQ	runtime·tls0(SB), DI
	PUSHQ	DI
	CALL	segsetup(SB)

	MOVQ	8(AX), DI
	PUSHQ	DI
	MOVQ	(AX), DI
	PUSHQ	DI
	// lgdt (%rsp)
	BYTE	$0x0f
	BYTE	$0x01
	BYTE	$0x14
	BYTE	$0x24
	POPQ	AX
	POPQ	AX
	POPQ	AX

	MOVQ	$(FSSEG << 3), AX
	PUSHQ	AX
	POPQ	FS

	MOVL	$(DATASEG << 3), AX
	//MOVL	AX, ES
	BYTE	$0x8e
	BYTE	$0xd8
	//MOVL	AX, DS
	BYTE	$0x8e
	BYTE	$0xc0
	//MOVL	AX, SS
	BYTE	$0x8e
	BYTE	$0xd0

	// i cannot fix CS via far call to a label because i don't know how to
	// call a label with plan9 compiler.
	CALL	fixcs(SB)

	// store through it, to make sure it works
	get_tls(BX)
	MOVQ	$0x123, g(BX)
	MOVQ	runtime·tls0(SB), AX
	CMPQ	AX, $0x123
	JEQ	h_ok
	MOVQ	$0x4242424242424242, AX
	PUSHQ	AX
	PUSHQ	$0
	CALL	runtime·pancake(SB)
h_ok:

	// set the per-goroutine and per-mach "registers"
	get_tls(BX)
	LEAQ	runtime·g0(SB), CX
	MOVQ	CX, g(BX)
	LEAQ	runtime·m0(SB), AX

	// save m->g0 = g0
	MOVQ	CX, m_g0(AX)
	// save m0 to g0->m
	MOVQ	AX, g_m(CX)

	CALL	int_setup(SB)
	CALL	proc_setup(SB)

	FINIT
	MOVQ	CR4, AX
	PUSHQ	AX
	MOVQ	CR0, AX
	PUSHQ	AX
	CALL	fpuinit(SB)

	CALL	runtime·sc_setup(SB)

	//MOVQ	CR0, AX
	//PUSHQ	AX
	//CALL	exam(SB)
	//POPQ	AX

	//CALL	pgtest(SB)
	//CALL	mmap_test(SB)

	CLD				// convention is D is always left cleared
	CALL	runtime·check(SB)

	//MOVL	16(SP), AX		// copy argc
	//MOVL	AX, 0(SP)
	//MOVQ	24(SP), AX		// copy argv
	//MOVQ	AX, 8(SP)
	MOVQ	$fakeargv(SB), AX
	PUSHQ	AX
	PUSHQ	$1
	CALL	runtime·args(SB)
	POPQ	AX
	POPQ	AX
	CALL	runtime·osinit(SB)
	CALL	runtime·schedinit(SB)

	// create a new goroutine to start program
	MOVQ	$runtime·main·f(SB), BP		// entry
	PUSHQ	BP
	PUSHQ	$0			// arg size
	CALL	runtime·newproc(SB)
	POPQ	AX
	POPQ	AX

	// start this M
	STI
	//CALL	clone_test(SB)
	CALL	runtime·mstart(SB)

	MOVL	$0xf1, 0xf1  // crash
	RET


TEXT rcr2(SB), NOSPLIT, $0-8
	MOVQ	CR2, AX
	MOVQ	AX, ret+0(FP)
	RET

TEXT tlbflush(SB), NOSPLIT, $0-0
	MOVQ	CR3, AX
	MOVQ	AX, CR3
	RET

TEXT lcr3(SB), NOSPLIT, $0-8
	MOVQ	pgtbl+0(FP), AX
	MOVQ	AX, CR3
	RET

TEXT runtime·Invlpg(SB), NOSPLIT, $0-8
	MOVQ	va+0(FP), AX
	INVLPG	(AX)
	RET

TEXT lidt(SB), NOSPLIT, $0-8
	MOVQ	idtpd+0(FP), AX
	MOVQ	8(AX), DI
	PUSHQ	DI
	MOVQ	(AX), DI
	PUSHQ	DI
	// lidt	(%rsp)
	BYTE	$0x0f
	BYTE	$0x01
	BYTE	$0x1c
	BYTE	$0x24
	POPQ	AX
	POPQ	AX
	RET

TEXT ltr(SB), NOSPLIT, $0-8
	MOVQ	seg+0(FP), AX
	// ltr	%ax
	BYTE $0x0f
	BYTE $0x00
	BYTE $0xd8
	RET

TEXT lcr0(SB), NOSPLIT, $0-8
	MOVQ	val+0(FP), AX
	MOVQ	AX, CR0
	RET

TEXT lcr4(SB), NOSPLIT, $0-8
	MOVQ	val+0(FP), AX
	MOVQ	AX, CR4
	RET

TEXT rdmsr(SB), NOSPLIT, $0-16
	MOVQ	reg+0(FP), CX
	RDMSR
	MOVL	DX, ret2+12(FP)
	MOVL	AX, ret1+8(FP)
	RET

// void wrmsr(uint64 reg, uint64 val)
TEXT wrmsr(SB), NOSPLIT, $0-16
	MOVQ	reg+0(FP), CX
	MOVL	vlo+8(FP), AX
	MOVL	vhi+12(FP), DX
	WRMSR
	RET

TEXT runtime·outb(SB), NOSPLIT, $0-0
	JMP outb(SB)
	
//void outb(int64 port, int64 val)
TEXT outb(SB), NOSPLIT, $0-16
	MOVL	reg+0(FP), DX
	MOVL	val+8(FP), AX
	// outb	%al, (%dx)
	BYTE	$0xee
	RET

TEXT runtime·inb(SB), NOSPLIT, $0-0
	JMP	inb(SB)

//int64 inb(int64 port)
TEXT inb(SB), NOSPLIT, $0-16
	MOVL	reg+0(FP), DX
	// inb	(%dx), %al
	BYTE	$0xec
	// movzbq %al, %rax
	BYTE $0x48
	BYTE $0x0f
	BYTE $0xb6
	BYTE $0xc0
	MOVQ	AX, ret+8(FP)
	RET

TEXT rflags(SB), NOSPLIT, $0-8
	// pushf
	BYTE	$0x9c
	POPQ	AX
	MOVQ	AX, ret+8(FP)
	RET

TEXT rrsp(SB), NOSPLIT, $0-8
	MOVQ	SP, AX
	MOVQ	AX, ret+0(FP)
	RET

TEXT cli(SB), NOSPLIT, $0-0
	CLI
	RET

TEXT sti(SB), NOSPLIT, $0-0
	STI
	RET

TEXT ·Sgdt(SB), NOSPLIT, $0-8
	MOVQ	ptr+0(FP), AX
	// sgdtl (%rax)
	BYTE	$0x0f
	BYTE	$0x01
	BYTE	$0x00
	RET

TEXT ·Sidt(SB), NOSPLIT, $0-8
	MOVQ	ptr+0(FP), AX
	// sidtl (%rax)
	BYTE	$0x0f
	BYTE	$0x01
	BYTE	$0x08
	RET

#define TRAP_TIMER      $32
TEXT hack_yield(SB), NOSPLIT, $0-0
	INT	TRAP_TIMER
	RET

#define IH_NOEC(num, fn)		\
TEXT fn(SB), NOSPLIT, $0-0;		\
	PUSHQ	$0;			\
	PUSHQ	$num;			\
	JMP	alltraps(SB);		\
	BYTE	$0xeb;			\
	BYTE	$0xfe;			\
	POPQ	AX;			\
	POPQ	AX;			\
	RET

#define IH_NOEC_LOOP(num, fn)		\
TEXT fn(SB), NOSPLIT, $0-0;		\
	PUSHQ	$0;			\
	PUSHQ	$num;			\
	BYTE	$0xeb;			\
	BYTE	$0xfe;			\
	JMP	alltraps(SB);		\
	BYTE	$0xeb;			\
	BYTE	$0xfe;			\
	POPQ	AX;			\
	POPQ	AX;			\
	RET

#define IH_EC(num, fn)			\
TEXT fn(SB), NOSPLIT, $0-0;		\
	PUSHQ	$num;			\
	JMP	alltraps(SB);		\
	BYTE	$0xeb;			\
	BYTE	$0xfe;			\
	POPQ	AX;			\
	RET

IH_NOEC( 0,Xdz )
IH_NOEC( 1,Xrz )
IH_NOEC( 2,Xnmi )
IH_NOEC( 3,Xbp )
IH_NOEC( 4,Xov )
IH_NOEC( 5,Xbnd )
IH_NOEC( 6,Xuo )
IH_NOEC( 7,Xnm )
IH_EC  ( 8,Xdf )
IH_NOEC( 9,Xrz2 )
IH_EC  (10,Xtss )
IH_EC  (11,Xsnp )
IH_EC  (12,Xssf )
IH_EC  (13,Xgp )
IH_EC  (14,Xpf )
IH_NOEC(15,Xrz3 )
IH_NOEC(16,Xmf )
IH_EC  (17,Xac )
IH_NOEC(18,Xmc )
IH_NOEC(19,Xfp )
IH_NOEC(20,Xve )
IH_NOEC(32,Xtimer )
IH_NOEC(47,Xspur )
IH_NOEC(64,Xsyscall )

#define IA32_FS_BASE   $0xc0000100UL

TEXT wrfsb(SB), NOSPLIT, $0-8
	get_tls(BX)
	MOVQ	val+0(FP), AX
	MOVQ	AX, g(BX)
	RET

TEXT rdfsb(SB), NOSPLIT, $0-8
	get_tls(BX)
	MOVQ	g(BX), AX
	MOVQ	AX, ret+0(FP)
	RET

TEXT alltraps(SB), NOSPLIT, $0-0
	// tf[15] = trapno
	// 15 + 1 pushes
	// pusha is not valid in 64bit mode!
	PUSHQ	AX

	PUSHQ	BX
	PUSHQ	CX
	PUSHQ	DX
	PUSHQ	DI
	PUSHQ	SI
	PUSHQ	BP
	PUSHQ	R8
	PUSHQ	R9
	PUSHQ	R10
	PUSHQ	R11
	PUSHQ	R12
	PUSHQ	R13
	PUSHQ	R14
	PUSHQ	R15

	// save fsbase
	MOVQ	IA32_FS_BASE, CX
	RDMSR
	SHLQ	$32, DX
	ORQ	DX, AX
	PUSHQ	AX

	MOVQ	SP, AX
	PUSHQ	AX

	CALL	trap(SB)
	// jmp self
	BYTE	$0xeb
	BYTE	$0xfe

TEXT trapret(SB), NOSPLIT, $0-16
	MOVQ	pmap+8(FP), BX
	MOVQ	tf+0(FP), AX	// tf is not on the callers stack frame, but in
				// threads[]
	MOVQ	AX, SP

	MOVQ	BX, CR3

	// restore fsbase
	MOVQ	IA32_FS_BASE, CX
	POPQ	AX
	MOVQ	AX, DX
	ANDQ	$((1 << 32) - 1), AX
	SHRQ	$32, DX
	WRMSR

	POPQ	R15
	POPQ	R14
	POPQ	R13
	POPQ	R12
	POPQ	R11
	POPQ	R10
	POPQ	R9
	POPQ	R8
	POPQ	BP
	POPQ	SI
	POPQ	DI
	POPQ	DX
	POPQ	CX
	POPQ	BX
	POPQ	AX
	// skip trapno and error code
	ADDQ	$16, SP

	// iretq
	BYTE	$0x48
	BYTE	$0xcf
	// jmp self
	BYTE	$0xeb
	BYTE	$0xfe

/*
 *  go-routine
 */

// void gosave(Gobuf*)
// save state in Gobuf; setjmp
TEXT runtime·gosave(SB), NOSPLIT, $0-8
	MOVQ	buf+0(FP), AX		// gobuf
	LEAQ	buf+0(FP), BX		// caller's SP
	MOVQ	BX, gobuf_sp(AX)
	MOVQ	0(SP), BX		// caller's PC
	MOVQ	BX, gobuf_pc(AX)
	MOVQ	$0, gobuf_ret(AX)
	MOVQ	$0, gobuf_ctxt(AX)
	get_tls(CX)
	MOVQ	g(CX), BX
	MOVQ	BX, gobuf_g(AX)
	RET

// void gogo(Gobuf*)
// restore state from Gobuf; longjmp
TEXT runtime·gogo(SB), NOSPLIT, $0-8
	MOVQ	buf+0(FP), BX		// gobuf
	MOVQ	gobuf_g(BX), DX
	MOVQ	0(DX), CX		// make sure g != nil
	get_tls(CX)
	MOVQ	DX, g(CX)
	MOVQ	gobuf_sp(BX), SP	// restore SP
	MOVQ	gobuf_ret(BX), AX
	MOVQ	gobuf_ctxt(BX), DX
	MOVQ	$0, gobuf_sp(BX)	// clear to help garbage collector
	MOVQ	$0, gobuf_ret(BX)
	MOVQ	$0, gobuf_ctxt(BX)
	MOVQ	gobuf_pc(BX), BX
	JMP	BX

// func mcall(fn func(*g))
// Switch to m->g0's stack, call fn(g).
// Fn must never return.  It should gogo(&g->sched)
// to keep running g.
TEXT runtime·mcall(SB), NOSPLIT, $0-8
	MOVQ	fn+0(FP), DI
	
	get_tls(CX)
	MOVQ	g(CX), AX	// save state in g->sched
	MOVQ	0(SP), BX	// caller's PC
	MOVQ	BX, (g_sched+gobuf_pc)(AX)
	LEAQ	fn+0(FP), BX	// caller's SP
	MOVQ	BX, (g_sched+gobuf_sp)(AX)
	MOVQ	AX, (g_sched+gobuf_g)(AX)

	// switch to m->g0 & its stack, call fn
	MOVQ	g(CX), BX
	MOVQ	g_m(BX), BX
	MOVQ	m_g0(BX), SI
	CMPQ	SI, AX	// if g == m->g0 call badmcall
	JNE	3(PC)
	MOVQ	$runtime·badmcall(SB), AX
	JMP	AX
	MOVQ	SI, g(CX)	// g = m->g0
	MOVQ	(g_sched+gobuf_sp)(SI), SP	// sp = m->g0->sched.sp
	PUSHQ	AX
	MOVQ	DI, DX
	MOVQ	0(DI), DI
	CALL	DI
	POPQ	AX
	MOVQ	$runtime·badmcall2(SB), AX
	JMP	AX
	RET

// switchtoM is a dummy routine that onM leaves at the bottom
// of the G stack.  We need to distinguish the routine that
// lives at the bottom of the G stack from the one that lives
// at the top of the M stack because the one at the top of
// the M stack terminates the stack walk (see topofstack()).
TEXT runtime·switchtoM(SB), NOSPLIT, $0-0
	RET

// func onM_signalok(fn func())
TEXT runtime·onM_signalok(SB), NOSPLIT, $0-8
	get_tls(CX)
	MOVQ	g(CX), AX	// AX = g
	MOVQ	g_m(AX), BX	// BX = m
	MOVQ	m_gsignal(BX), DX	// DX = gsignal
	CMPQ	AX, DX
	JEQ	ongsignal
	JMP	runtime·onM(SB)

ongsignal:
	MOVQ	fn+0(FP), DI	// DI = fn
	MOVQ	DI, DX
	MOVQ	0(DI), DI
	CALL	DI
	RET

// func onM(fn func())
TEXT runtime·onM(SB), NOSPLIT, $0-8
	MOVQ	fn+0(FP), DI	// DI = fn
	get_tls(CX)
	MOVQ	g(CX), AX	// AX = g
	MOVQ	g_m(AX), BX	// BX = m

	MOVQ	m_g0(BX), DX	// DX = g0
	CMPQ	AX, DX
	JEQ	onm

	MOVQ	m_curg(BX), BP
	CMPQ	AX, BP
	JEQ	oncurg
	
	// Not g0, not curg. Must be gsignal, but that's not allowed.
	// Hide call from linker nosplit analysis.
	MOVQ	$runtime·badonm(SB), AX
	CALL	AX

oncurg:
	// save our state in g->sched.  Pretend to
	// be switchtoM if the G stack is scanned.
	MOVQ	$runtime·switchtoM(SB), BP
	MOVQ	BP, (g_sched+gobuf_pc)(AX)
	MOVQ	SP, (g_sched+gobuf_sp)(AX)
	MOVQ	AX, (g_sched+gobuf_g)(AX)

	// switch to g0
	MOVQ	DX, g(CX)
	MOVQ	(g_sched+gobuf_sp)(DX), BX
	// make it look like mstart called onM on g0, to stop traceback
	SUBQ	$8, BX
	MOVQ	$runtime·mstart(SB), DX
	MOVQ	DX, 0(BX)
	MOVQ	BX, SP

	// call target function
	MOVQ	DI, DX
	MOVQ	0(DI), DI
	CALL	DI

	// switch back to g
	get_tls(CX)
	MOVQ	g(CX), AX
	MOVQ	g_m(AX), BX
	MOVQ	m_curg(BX), AX
	MOVQ	AX, g(CX)
	MOVQ	(g_sched+gobuf_sp)(AX), SP
	MOVQ	$0, (g_sched+gobuf_sp)(AX)
	RET

onm:
	// already on m stack, just call directly
	MOVQ	DI, DX
	MOVQ	0(DI), DI
	CALL	DI
	RET

/*
 * support for morestack
 */

// Called during function prolog when more stack is needed.
//
// The traceback routines see morestack on a g0 as being
// the top of a stack (for example, morestack calling newstack
// calling the scheduler calling newm calling gc), so we must
// record an argument size. For that purpose, it has no arguments.
TEXT runtime·morestack(SB),NOSPLIT,$0-0
	// Cannot grow scheduler stack (m->g0).
	get_tls(CX)
	MOVQ	g(CX), BX
	MOVQ	g_m(BX), BX
	MOVQ	m_g0(BX), SI
	CMPQ	g(CX), SI
	JNE	2(PC)
	INT	$3

	// Cannot grow signal stack (m->gsignal).
	MOVQ	m_gsignal(BX), SI
	CMPQ	g(CX), SI
	JNE	2(PC)
	INT	$3

	// Called from f.
	// Set m->morebuf to f's caller.
	MOVQ	8(SP), AX	// f's caller's PC
	MOVQ	AX, (m_morebuf+gobuf_pc)(BX)
	LEAQ	16(SP), AX	// f's caller's SP
	MOVQ	AX, (m_morebuf+gobuf_sp)(BX)
	get_tls(CX)
	MOVQ	g(CX), SI
	MOVQ	SI, (m_morebuf+gobuf_g)(BX)

	// Set g->sched to context in f.
	MOVQ	0(SP), AX // f's PC
	MOVQ	AX, (g_sched+gobuf_pc)(SI)
	MOVQ	SI, (g_sched+gobuf_g)(SI)
	LEAQ	8(SP), AX // f's SP
	MOVQ	AX, (g_sched+gobuf_sp)(SI)
	MOVQ	DX, (g_sched+gobuf_ctxt)(SI)

	// Call newstack on m->g0's stack.
	MOVQ	m_g0(BX), BP
	MOVQ	BP, g(CX)
	MOVQ	(g_sched+gobuf_sp)(BP), SP
	CALL	runtime·newstack(SB)
	MOVQ	$0, 0x1003	// crash if newstack returns
	RET

// morestack but not preserving ctxt.
TEXT runtime·morestack_noctxt(SB),NOSPLIT,$0
	MOVL	$0, DX
	JMP	runtime·morestack(SB)

// reflectcall: call a function with the given argument list
// func call(f *FuncVal, arg *byte, argsize, retoffset uint32).
// we don't have variable-sized frames, so we use a small number
// of constant-sized-frame functions to encode a few bits of size in the pc.
// Caution: ugly multiline assembly macros in your future!

#define DISPATCH(NAME,MAXSIZE)		\
	CMPQ	CX, $MAXSIZE;		\
	JA	3(PC);			\
	MOVQ	$NAME(SB), AX;	\
	JMP	AX
// Note: can't just "JMP NAME(SB)" - bad inlining results.

TEXT runtime·reflectcall(SB), NOSPLIT, $0-24
	MOVLQZX argsize+16(FP), CX
	DISPATCH(runtime·call16, 16)
	DISPATCH(runtime·call32, 32)
	DISPATCH(runtime·call64, 64)
	DISPATCH(runtime·call128, 128)
	DISPATCH(runtime·call256, 256)
	DISPATCH(runtime·call512, 512)
	DISPATCH(runtime·call1024, 1024)
	DISPATCH(runtime·call2048, 2048)
	DISPATCH(runtime·call4096, 4096)
	DISPATCH(runtime·call8192, 8192)
	DISPATCH(runtime·call16384, 16384)
	DISPATCH(runtime·call32768, 32768)
	DISPATCH(runtime·call65536, 65536)
	DISPATCH(runtime·call131072, 131072)
	DISPATCH(runtime·call262144, 262144)
	DISPATCH(runtime·call524288, 524288)
	DISPATCH(runtime·call1048576, 1048576)
	DISPATCH(runtime·call2097152, 2097152)
	DISPATCH(runtime·call4194304, 4194304)
	DISPATCH(runtime·call8388608, 8388608)
	DISPATCH(runtime·call16777216, 16777216)
	DISPATCH(runtime·call33554432, 33554432)
	DISPATCH(runtime·call67108864, 67108864)
	DISPATCH(runtime·call134217728, 134217728)
	DISPATCH(runtime·call268435456, 268435456)
	DISPATCH(runtime·call536870912, 536870912)
	DISPATCH(runtime·call1073741824, 1073741824)
	MOVQ	$runtime·badreflectcall(SB), AX
	JMP	AX

// Argument map for the callXX frames.  Each has one stack map.
DATA gcargs_reflectcall<>+0x00(SB)/4, $1  // 1 stackmap
DATA gcargs_reflectcall<>+0x04(SB)/4, $6  // 3 words
DATA gcargs_reflectcall<>+0x08(SB)/1, $(const_BitsPointer+(const_BitsPointer<<2)+(const_BitsScalar<<4))
GLOBL gcargs_reflectcall<>(SB),RODATA,$12

// callXX frames have no locals
DATA gclocals_reflectcall<>+0x00(SB)/4, $1  // 1 stackmap
DATA gclocals_reflectcall<>+0x04(SB)/4, $0  // 0 locals
GLOBL gclocals_reflectcall<>(SB),RODATA,$8

#define CALLFN(NAME,MAXSIZE)			\
TEXT NAME(SB), WRAPPER, $MAXSIZE-24;		\
	FUNCDATA $FUNCDATA_ArgsPointerMaps,gcargs_reflectcall<>(SB);	\
	FUNCDATA $FUNCDATA_LocalsPointerMaps,gclocals_reflectcall<>(SB);\
	/* copy arguments to stack */		\
	MOVQ	argptr+8(FP), SI;		\
	MOVLQZX argsize+16(FP), CX;		\
	MOVQ	SP, DI;				\
	REP;MOVSB;				\
	/* call function */			\
	MOVQ	f+0(FP), DX;			\
	PCDATA  $PCDATA_StackMapIndex, $0;	\
	CALL	(DX);				\
	/* copy return values back */		\
	MOVQ	argptr+8(FP), DI;		\
	MOVLQZX	argsize+16(FP), CX;		\
	MOVLQZX retoffset+20(FP), BX;		\
	MOVQ	SP, SI;				\
	ADDQ	BX, DI;				\
	ADDQ	BX, SI;				\
	SUBQ	BX, CX;				\
	REP;MOVSB;				\
	RET

CALLFN(runtime·call16, 16)
CALLFN(runtime·call32, 32)
CALLFN(runtime·call64, 64)
CALLFN(runtime·call128, 128)
CALLFN(runtime·call256, 256)
CALLFN(runtime·call512, 512)
CALLFN(runtime·call1024, 1024)
CALLFN(runtime·call2048, 2048)
CALLFN(runtime·call4096, 4096)
CALLFN(runtime·call8192, 8192)
CALLFN(runtime·call16384, 16384)
CALLFN(runtime·call32768, 32768)
CALLFN(runtime·call65536, 65536)
CALLFN(runtime·call131072, 131072)
CALLFN(runtime·call262144, 262144)
CALLFN(runtime·call524288, 524288)
CALLFN(runtime·call1048576, 1048576)
CALLFN(runtime·call2097152, 2097152)
CALLFN(runtime·call4194304, 4194304)
CALLFN(runtime·call8388608, 8388608)
CALLFN(runtime·call16777216, 16777216)
CALLFN(runtime·call33554432, 33554432)
CALLFN(runtime·call67108864, 67108864)
CALLFN(runtime·call134217728, 134217728)
CALLFN(runtime·call268435456, 268435456)
CALLFN(runtime·call536870912, 536870912)
CALLFN(runtime·call1073741824, 1073741824)

// bool cas(int32 *val, int32 old, int32 new)
// Atomically:
//	if(*val == old){
//		*val = new;
//		return 1;
//	} else
//		return 0;
TEXT runtime·cas(SB), NOSPLIT, $0-17
	MOVQ	ptr+0(FP), BX
	MOVL	old+8(FP), AX
	MOVL	new+12(FP), CX
	LOCK
	CMPXCHGL	CX, 0(BX)
	JZ 4(PC)
	MOVL	$0, AX
	MOVB	AX, ret+16(FP)
	RET
	MOVL	$1, AX
	MOVB	AX, ret+16(FP)
	RET

// bool	runtime·cas64(uint64 *val, uint64 old, uint64 new)
// Atomically:
//	if(*val == *old){
//		*val = new;
//		return 1;
//	} else {
//		return 0;
//	}
TEXT runtime·cas64(SB), NOSPLIT, $0-25
	MOVQ	ptr+0(FP), BX
	MOVQ	old+8(FP), AX
	MOVQ	new+16(FP), CX
	LOCK
	CMPXCHGQ	CX, 0(BX)
	JNZ	cas64_fail
	MOVL	$1, AX
	MOVB	AX, ret+24(FP)
	RET
cas64_fail:
	MOVL	$0, AX
	MOVB	AX, ret+24(FP)
	RET
	
TEXT runtime·casuintptr(SB), NOSPLIT, $0-25
	JMP	runtime·cas64(SB)

TEXT runtime·atomicloaduintptr(SB), NOSPLIT, $0-16
	JMP	runtime·atomicload64(SB)

TEXT runtime·atomicloaduint(SB), NOSPLIT, $0-16
	JMP	runtime·atomicload64(SB)

// bool casp(void **val, void *old, void *new)
// Atomically:
//	if(*val == old){
//		*val = new;
//		return 1;
//	} else
//		return 0;
TEXT runtime·casp(SB), NOSPLIT, $0-25
	MOVQ	ptr+0(FP), BX
	MOVQ	old+8(FP), AX
	MOVQ	new+16(FP), CX
	LOCK
	CMPXCHGQ	CX, 0(BX)
	JZ 4(PC)
	MOVL	$0, AX
	MOVB	AX, ret+24(FP)
	RET
	MOVL	$1, AX
	MOVB	AX, ret+24(FP)
	RET

// uint32 xadd(uint32 volatile *val, int32 delta)
// Atomically:
//	*val += delta;
//	return *val;
TEXT runtime·xadd(SB), NOSPLIT, $0-20
	MOVQ	ptr+0(FP), BX
	MOVL	delta+8(FP), AX
	MOVL	AX, CX
	LOCK
	XADDL	AX, 0(BX)
	ADDL	CX, AX
	MOVL	AX, ret+16(FP)
	RET

TEXT runtime·xadd64(SB), NOSPLIT, $0-24
	MOVQ	ptr+0(FP), BX
	MOVQ	delta+8(FP), AX
	MOVQ	AX, CX
	LOCK
	XADDQ	AX, 0(BX)
	ADDQ	CX, AX
	MOVQ	AX, ret+16(FP)
	RET

TEXT runtime·xchg(SB), NOSPLIT, $0-20
	MOVQ	ptr+0(FP), BX
	MOVL	new+8(FP), AX
	XCHGL	AX, 0(BX)
	MOVL	AX, ret+16(FP)
	RET

TEXT runtime·xchg64(SB), NOSPLIT, $0-24
	MOVQ	ptr+0(FP), BX
	MOVQ	new+8(FP), AX
	XCHGQ	AX, 0(BX)
	MOVQ	AX, ret+16(FP)
	RET

TEXT runtime·xchgp(SB), NOSPLIT, $0-24
	MOVQ	ptr+0(FP), BX
	MOVQ	new+8(FP), AX
	XCHGQ	AX, 0(BX)
	MOVQ	AX, ret+16(FP)
	RET

TEXT runtime·xchguintptr(SB), NOSPLIT, $0-24
	JMP	runtime·xchg64(SB)

TEXT runtime·procyield(SB),NOSPLIT,$0-0
	MOVL	cycles+0(FP), AX
again:
	PAUSE
	SUBL	$1, AX
	JNZ	again
	RET

TEXT runtime·atomicstorep(SB), NOSPLIT, $0-16
	MOVQ	ptr+0(FP), BX
	MOVQ	val+8(FP), AX
	XCHGQ	AX, 0(BX)
	RET

TEXT runtime·atomicstore(SB), NOSPLIT, $0-12
	MOVQ	ptr+0(FP), BX
	MOVL	val+8(FP), AX
	XCHGL	AX, 0(BX)
	RET

TEXT runtime·atomicstore64(SB), NOSPLIT, $0-16
	MOVQ	ptr+0(FP), BX
	MOVQ	val+8(FP), AX
	XCHGQ	AX, 0(BX)
	RET

// void	runtime·atomicor8(byte volatile*, byte);
TEXT runtime·atomicor8(SB), NOSPLIT, $0-9
	MOVQ	ptr+0(FP), AX
	MOVB	val+8(FP), BX
	LOCK
	ORB	BX, (AX)
	RET

// void jmpdefer(fn, sp);
// called from deferreturn.
// 1. pop the caller
// 2. sub 5 bytes from the callers return
// 3. jmp to the argument
TEXT runtime·jmpdefer(SB), NOSPLIT, $0-16
	MOVQ	fv+0(FP), DX	// fn
	MOVQ	argp+8(FP), BX	// caller sp
	LEAQ	-8(BX), SP	// caller sp after CALL
	SUBQ	$5, (SP)	// return to CALL again
	MOVQ	0(DX), BX
	JMP	BX	// but first run the deferred function

// Save state of caller into g->sched. Smashes R8, R9.
TEXT gosave<>(SB),NOSPLIT,$0
	get_tls(R8)
	MOVQ	g(R8), R8
	MOVQ	0(SP), R9
	MOVQ	R9, (g_sched+gobuf_pc)(R8)
	LEAQ	8(SP), R9
	MOVQ	R9, (g_sched+gobuf_sp)(R8)
	MOVQ	$0, (g_sched+gobuf_ret)(R8)
	MOVQ	$0, (g_sched+gobuf_ctxt)(R8)
	RET

// asmcgocall(void(*fn)(void*), void *arg)
// Call fn(arg) on the scheduler stack,
// aligned appropriately for the gcc ABI.
// See cgocall.c for more details.
TEXT ·asmcgocall(SB),NOSPLIT,$0-16
	MOVQ	fn+0(FP), AX
	MOVQ	arg+8(FP), BX
	CALL	asmcgocall<>(SB)
	RET

TEXT ·asmcgocall_errno(SB),NOSPLIT,$0-20
	MOVQ	fn+0(FP), AX
	MOVQ	arg+8(FP), BX
	CALL	asmcgocall<>(SB)
	MOVL	AX, ret+16(FP)
	RET

// asmcgocall common code. fn in AX, arg in BX. returns errno in AX.
TEXT asmcgocall<>(SB),NOSPLIT,$0-0
	MOVQ	SP, DX

	// Figure out if we need to switch to m->g0 stack.
	// We get called to create new OS threads too, and those
	// come in on the m->g0 stack already.
	get_tls(CX)
	MOVQ	g(CX), BP
	MOVQ	g_m(BP), BP
	MOVQ	m_g0(BP), SI
	MOVQ	g(CX), DI
	CMPQ	SI, DI
	JEQ	nosave
	MOVQ	m_gsignal(BP), SI
	CMPQ	SI, DI
	JEQ	nosave
	
	MOVQ	m_g0(BP), SI
	CALL	gosave<>(SB)
	MOVQ	SI, g(CX)
	MOVQ	(g_sched+gobuf_sp)(SI), SP
nosave:

	// Now on a scheduling stack (a pthread-created stack).
	// Make sure we have enough room for 4 stack-backed fast-call
	// registers as per windows amd64 calling convention.
	SUBQ	$64, SP
	ANDQ	$~15, SP	// alignment for gcc ABI
	MOVQ	DI, 48(SP)	// save g
	MOVQ	(g_stack+stack_hi)(DI), DI
	SUBQ	DX, DI
	MOVQ	DI, 40(SP)	// save depth in stack (can't just save SP, as stack might be copied during a callback)
	MOVQ	BX, DI		// DI = first argument in AMD64 ABI
	MOVQ	BX, CX		// CX = first argument in Win64
	CALL	AX

	// Restore registers, g, stack pointer.
	get_tls(CX)
	MOVQ	48(SP), DI
	MOVQ	(g_stack+stack_hi)(DI), SI
	SUBQ	40(SP), SI
	MOVQ	DI, g(CX)
	MOVQ	SI, SP
	RET

// cgocallback(void (*fn)(void*), void *frame, uintptr framesize)
// Turn the fn into a Go func (by taking its address) and call
// cgocallback_gofunc.
TEXT runtime·cgocallback(SB),NOSPLIT,$24-24
	LEAQ	fn+0(FP), AX
	MOVQ	AX, 0(SP)
	MOVQ	frame+8(FP), AX
	MOVQ	AX, 8(SP)
	MOVQ	framesize+16(FP), AX
	MOVQ	AX, 16(SP)
	MOVQ	$runtime·cgocallback_gofunc(SB), AX
	CALL	AX
	RET

// cgocallback_gofunc(FuncVal*, void *frame, uintptr framesize)
// See cgocall.c for more details.
TEXT ·cgocallback_gofunc(SB),NOSPLIT,$8-24
	NO_LOCAL_POINTERS

	// If g is nil, Go did not create the current thread.
	// Call needm to obtain one m for temporary use.
	// In this case, we're running on the thread stack, so there's
	// lots of space, but the linker doesn't know. Hide the call from
	// the linker analysis by using an indirect call through AX.
	get_tls(CX)
#ifdef GOOS_windows
	MOVL	$0, BP
	CMPQ	CX, $0
	JEQ	2(PC)
#endif
	MOVQ	g(CX), BP
	CMPQ	BP, $0
	JEQ	needm
	MOVQ	g_m(BP), BP
	MOVQ	BP, R8 // holds oldm until end of function
	JMP	havem
needm:
	MOVQ	$0, 0(SP)
	MOVQ	$runtime·needm(SB), AX
	CALL	AX
	MOVQ	0(SP), R8
	get_tls(CX)
	MOVQ	g(CX), BP
	MOVQ	g_m(BP), BP

havem:
	// Now there's a valid m, and we're running on its m->g0.
	// Save current m->g0->sched.sp on stack and then set it to SP.
	// Save current sp in m->g0->sched.sp in preparation for
	// switch back to m->curg stack.
	// NOTE: unwindm knows that the saved g->sched.sp is at 0(SP).
	MOVQ	m_g0(BP), SI
	MOVQ	(g_sched+gobuf_sp)(SI), AX
	MOVQ	AX, 0(SP)
	MOVQ	SP, (g_sched+gobuf_sp)(SI)

	// Switch to m->curg stack and call runtime.cgocallbackg.
	// Because we are taking over the execution of m->curg
	// but *not* resuming what had been running, we need to
	// save that information (m->curg->sched) so we can restore it.
	// We can restore m->curg->sched.sp easily, because calling
	// runtime.cgocallbackg leaves SP unchanged upon return.
	// To save m->curg->sched.pc, we push it onto the stack.
	// This has the added benefit that it looks to the traceback
	// routine like cgocallbackg is going to return to that
	// PC (because the frame we allocate below has the same
	// size as cgocallback_gofunc's frame declared above)
	// so that the traceback will seamlessly trace back into
	// the earlier calls.
	//
	// In the new goroutine, 0(SP) holds the saved R8.
	MOVQ	m_curg(BP), SI
	MOVQ	SI, g(CX)
	MOVQ	(g_sched+gobuf_sp)(SI), DI  // prepare stack as DI
	MOVQ	(g_sched+gobuf_pc)(SI), BP
	MOVQ	BP, -8(DI)
	LEAQ	-(8+8)(DI), SP
	MOVQ	R8, 0(SP)
	CALL	runtime·cgocallbackg(SB)
	MOVQ	0(SP), R8

	// Restore g->sched (== m->curg->sched) from saved values.
	get_tls(CX)
	MOVQ	g(CX), SI
	MOVQ	8(SP), BP
	MOVQ	BP, (g_sched+gobuf_pc)(SI)
	LEAQ	(8+8)(SP), DI
	MOVQ	DI, (g_sched+gobuf_sp)(SI)

	// Switch back to m->g0's stack and restore m->g0->sched.sp.
	// (Unlike m->curg, the g0 goroutine never uses sched.pc,
	// so we do not have to restore it.)
	MOVQ	g(CX), BP
	MOVQ	g_m(BP), BP
	MOVQ	m_g0(BP), SI
	MOVQ	SI, g(CX)
	MOVQ	(g_sched+gobuf_sp)(SI), SP
	MOVQ	0(SP), AX
	MOVQ	AX, (g_sched+gobuf_sp)(SI)
	
	// If the m on entry was nil, we called needm above to borrow an m
	// for the duration of the call. Since the call is over, return it with dropm.
	CMPQ	R8, $0
	JNE 3(PC)
	MOVQ	$runtime·dropm(SB), AX
	CALL	AX

	// Done!
	RET

// void setg(G*); set g. for use by needm.
TEXT runtime·setg(SB), NOSPLIT, $0-8
	MOVQ	gg+0(FP), BX
#ifdef GOOS_windows
	CMPQ	BX, $0
	JNE	settls
	MOVQ	$0, 0x28(GS)
	RET
settls:
	MOVQ	g_m(BX), AX
	LEAQ	m_tls(AX), AX
	MOVQ	AX, 0x28(GS)
#endif
	get_tls(CX)
	MOVQ	BX, g(CX)
	RET

// void setg_gcc(G*); set g called from gcc.
TEXT setg_gcc<>(SB),NOSPLIT,$0
	get_tls(AX)
	MOVQ	DI, g(AX)
	RET

// check that SP is in range [g->stack.lo, g->stack.hi)
TEXT runtime·stackcheck(SB), NOSPLIT, $0-0
	get_tls(CX)
	MOVQ	g(CX), AX
	CMPQ	(g_stack+stack_hi)(AX), SP
	JHI	2(PC)
	INT	$3
	CMPQ	SP, (g_stack+stack_lo)(AX)
	JHI	2(PC)
	INT	$3
	RET

TEXT runtime·getcallerpc(SB),NOSPLIT,$0-16
	MOVQ	argp+0(FP),AX		// addr of first arg
	MOVQ	-8(AX),AX		// get calling pc
	MOVQ	AX, ret+8(FP)
	RET

TEXT runtime·gogetcallerpc(SB),NOSPLIT,$0-16
	MOVQ	p+0(FP),AX		// addr of first arg
	MOVQ	-8(AX),AX		// get calling pc
	MOVQ	AX,ret+8(FP)
	RET

TEXT runtime·setcallerpc(SB),NOSPLIT,$0-16
	MOVQ	argp+0(FP),AX		// addr of first arg
	MOVQ	pc+8(FP), BX
	MOVQ	BX, -8(AX)		// set calling pc
	RET

TEXT runtime·getcallersp(SB),NOSPLIT,$0-16
	MOVQ	argp+0(FP), AX
	MOVQ	AX, ret+8(FP)
	RET

// func gogetcallersp(p unsafe.Pointer) uintptr
TEXT runtime·gogetcallersp(SB),NOSPLIT,$0-16
	MOVQ	p+0(FP),AX		// addr of first arg
	MOVQ	AX, ret+8(FP)
	RET

// int64 runtime·cputicks(void)
TEXT runtime·cputicks(SB),NOSPLIT,$0-0
	RDTSC
	SHLQ	$32, DX
	ADDQ	DX, AX
	MOVQ	AX, ret+0(FP)
	RET

TEXT runtime·gocputicks(SB),NOSPLIT,$0-8
	RDTSC
	SHLQ    $32, DX
	ADDQ    DX, AX
	MOVQ    AX, ret+0(FP)
	RET

// hash function using AES hardware instructions
TEXT runtime·aeshash(SB),NOSPLIT,$0-32
	MOVQ	p+0(FP), AX	// ptr to data
	MOVQ	s+8(FP), CX	// size
	JMP	runtime·aeshashbody(SB)

TEXT runtime·aeshashstr(SB),NOSPLIT,$0-32
	MOVQ	p+0(FP), AX	// ptr to string struct
	// s+8(FP) is ignored, it is always sizeof(String)
	MOVQ	8(AX), CX	// length of string
	MOVQ	(AX), AX	// string data
	JMP	runtime·aeshashbody(SB)

// AX: data
// CX: length
TEXT runtime·aeshashbody(SB),NOSPLIT,$0-32
	MOVQ	h+16(FP), X0	// seed to low 64 bits of xmm0
	PINSRQ	$1, CX, X0	// size to high 64 bits of xmm0
	MOVO	runtime·aeskeysched+0(SB), X2
	MOVO	runtime·aeskeysched+16(SB), X3
	CMPQ	CX, $16
	JB	aessmall
aesloop:
	CMPQ	CX, $16
	JBE	aesloopend
	MOVOU	(AX), X1
	AESENC	X2, X0
	AESENC	X1, X0
	SUBQ	$16, CX
	ADDQ	$16, AX
	JMP	aesloop
// 1-16 bytes remaining
aesloopend:
	// This load may overlap with the previous load above.
	// We'll hash some bytes twice, but that's ok.
	MOVOU	-16(AX)(CX*1), X1
	JMP	partial
// 0-15 bytes
aessmall:
	TESTQ	CX, CX
	JE	finalize	// 0 bytes

	CMPB	AX, $0xf0
	JA	highpartial

	// 16 bytes loaded at this address won't cross
	// a page boundary, so we can load it directly.
	MOVOU	(AX), X1
	ADDQ	CX, CX
	MOVQ	$masks<>(SB), BP
	PAND	(BP)(CX*8), X1
	JMP	partial
highpartial:
	// address ends in 1111xxxx.  Might be up against
	// a page boundary, so load ending at last byte.
	// Then shift bytes down using pshufb.
	MOVOU	-16(AX)(CX*1), X1
	ADDQ	CX, CX
	MOVQ	$shifts<>(SB), BP
	PSHUFB	(BP)(CX*8), X1
partial:
	// incorporate partial block into hash
	AESENC	X3, X0
	AESENC	X1, X0
finalize:	
	// finalize hash
	AESENC	X2, X0
	AESENC	X3, X0
	AESENC	X2, X0
	MOVQ	X0, res+24(FP)
	RET

TEXT runtime·aeshash32(SB),NOSPLIT,$0-32
	MOVQ	p+0(FP), AX	// ptr to data
	// s+8(FP) is ignored, it is always sizeof(int32)
	MOVQ	h+16(FP), X0	// seed
	PINSRD	$2, (AX), X0	// data
	AESENC	runtime·aeskeysched+0(SB), X0
	AESENC	runtime·aeskeysched+16(SB), X0
	AESENC	runtime·aeskeysched+0(SB), X0
	MOVQ	X0, ret+24(FP)
	RET

TEXT runtime·aeshash64(SB),NOSPLIT,$0-32
	MOVQ	p+0(FP), AX	// ptr to data
	// s+8(FP) is ignored, it is always sizeof(int64)
	MOVQ	h+16(FP), X0	// seed
	PINSRQ	$1, (AX), X0	// data
	AESENC	runtime·aeskeysched+0(SB), X0
	AESENC	runtime·aeskeysched+16(SB), X0
	AESENC	runtime·aeskeysched+0(SB), X0
	MOVQ	X0, ret+24(FP)
	RET

// simple mask to get rid of data in the high part of the register.
DATA masks<>+0x00(SB)/8, $0x0000000000000000
DATA masks<>+0x08(SB)/8, $0x0000000000000000
DATA masks<>+0x10(SB)/8, $0x00000000000000ff
DATA masks<>+0x18(SB)/8, $0x0000000000000000
DATA masks<>+0x20(SB)/8, $0x000000000000ffff
DATA masks<>+0x28(SB)/8, $0x0000000000000000
DATA masks<>+0x30(SB)/8, $0x0000000000ffffff
DATA masks<>+0x38(SB)/8, $0x0000000000000000
DATA masks<>+0x40(SB)/8, $0x00000000ffffffff
DATA masks<>+0x48(SB)/8, $0x0000000000000000
DATA masks<>+0x50(SB)/8, $0x000000ffffffffff
DATA masks<>+0x58(SB)/8, $0x0000000000000000
DATA masks<>+0x60(SB)/8, $0x0000ffffffffffff
DATA masks<>+0x68(SB)/8, $0x0000000000000000
DATA masks<>+0x70(SB)/8, $0x00ffffffffffffff
DATA masks<>+0x78(SB)/8, $0x0000000000000000
DATA masks<>+0x80(SB)/8, $0xffffffffffffffff
DATA masks<>+0x88(SB)/8, $0x0000000000000000
DATA masks<>+0x90(SB)/8, $0xffffffffffffffff
DATA masks<>+0x98(SB)/8, $0x00000000000000ff
DATA masks<>+0xa0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xa8(SB)/8, $0x000000000000ffff
DATA masks<>+0xb0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xb8(SB)/8, $0x0000000000ffffff
DATA masks<>+0xc0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xc8(SB)/8, $0x00000000ffffffff
DATA masks<>+0xd0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xd8(SB)/8, $0x000000ffffffffff
DATA masks<>+0xe0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xe8(SB)/8, $0x0000ffffffffffff
DATA masks<>+0xf0(SB)/8, $0xffffffffffffffff
DATA masks<>+0xf8(SB)/8, $0x00ffffffffffffff
GLOBL masks<>(SB),RODATA,$256

// these are arguments to pshufb.  They move data down from
// the high bytes of the register to the low bytes of the register.
// index is how many bytes to move.
DATA shifts<>+0x00(SB)/8, $0x0000000000000000
DATA shifts<>+0x08(SB)/8, $0x0000000000000000
DATA shifts<>+0x10(SB)/8, $0xffffffffffffff0f
DATA shifts<>+0x18(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x20(SB)/8, $0xffffffffffff0f0e
DATA shifts<>+0x28(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x30(SB)/8, $0xffffffffff0f0e0d
DATA shifts<>+0x38(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x40(SB)/8, $0xffffffff0f0e0d0c
DATA shifts<>+0x48(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x50(SB)/8, $0xffffff0f0e0d0c0b
DATA shifts<>+0x58(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x60(SB)/8, $0xffff0f0e0d0c0b0a
DATA shifts<>+0x68(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x70(SB)/8, $0xff0f0e0d0c0b0a09
DATA shifts<>+0x78(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x80(SB)/8, $0x0f0e0d0c0b0a0908
DATA shifts<>+0x88(SB)/8, $0xffffffffffffffff
DATA shifts<>+0x90(SB)/8, $0x0e0d0c0b0a090807
DATA shifts<>+0x98(SB)/8, $0xffffffffffffff0f
DATA shifts<>+0xa0(SB)/8, $0x0d0c0b0a09080706
DATA shifts<>+0xa8(SB)/8, $0xffffffffffff0f0e
DATA shifts<>+0xb0(SB)/8, $0x0c0b0a0908070605
DATA shifts<>+0xb8(SB)/8, $0xffffffffff0f0e0d
DATA shifts<>+0xc0(SB)/8, $0x0b0a090807060504
DATA shifts<>+0xc8(SB)/8, $0xffffffff0f0e0d0c
DATA shifts<>+0xd0(SB)/8, $0x0a09080706050403
DATA shifts<>+0xd8(SB)/8, $0xffffff0f0e0d0c0b
DATA shifts<>+0xe0(SB)/8, $0x0908070605040302
DATA shifts<>+0xe8(SB)/8, $0xffff0f0e0d0c0b0a
DATA shifts<>+0xf0(SB)/8, $0x0807060504030201
DATA shifts<>+0xf8(SB)/8, $0xff0f0e0d0c0b0a09
GLOBL shifts<>(SB),RODATA,$256

TEXT runtime·memeq(SB),NOSPLIT,$0-25
	MOVQ	a+0(FP), SI
	MOVQ	b+8(FP), DI
	MOVQ	size+16(FP), BX
	CALL	runtime·memeqbody(SB)
	MOVB	AX, ret+24(FP)
	RET

// eqstring tests whether two strings are equal.
// See runtime_test.go:eqstring_generic for
// equivalent Go code.
TEXT runtime·eqstring(SB),NOSPLIT,$0-33
	MOVQ	s1len+8(FP), AX
	MOVQ	s2len+24(FP), BX
	CMPQ	AX, BX
	JNE	different
	MOVQ	s1str+0(FP), SI
	MOVQ	s2str+16(FP), DI
	CMPQ	SI, DI
	JEQ	same
	CALL	runtime·memeqbody(SB)
	MOVB	AX, v+32(FP)
	RET
same:
	MOVB	$1, v+32(FP)
	RET
different:
	MOVB	$0, v+32(FP)
	RET

// a in SI
// b in DI
// count in BX
TEXT runtime·memeqbody(SB),NOSPLIT,$0-0
	XORQ	AX, AX

	CMPQ	BX, $8
	JB	small
	
	// 64 bytes at a time using xmm registers
hugeloop:
	CMPQ	BX, $64
	JB	bigloop
	MOVOU	(SI), X0
	MOVOU	(DI), X1
	MOVOU	16(SI), X2
	MOVOU	16(DI), X3
	MOVOU	32(SI), X4
	MOVOU	32(DI), X5
	MOVOU	48(SI), X6
	MOVOU	48(DI), X7
	PCMPEQB	X1, X0
	PCMPEQB	X3, X2
	PCMPEQB	X5, X4
	PCMPEQB	X7, X6
	PAND	X2, X0
	PAND	X6, X4
	PAND	X4, X0
	PMOVMSKB X0, DX
	ADDQ	$64, SI
	ADDQ	$64, DI
	SUBQ	$64, BX
	CMPL	DX, $0xffff
	JEQ	hugeloop
	RET

	// 8 bytes at a time using 64-bit register
bigloop:
	CMPQ	BX, $8
	JBE	leftover
	MOVQ	(SI), CX
	MOVQ	(DI), DX
	ADDQ	$8, SI
	ADDQ	$8, DI
	SUBQ	$8, BX
	CMPQ	CX, DX
	JEQ	bigloop
	RET

	// remaining 0-8 bytes
leftover:
	MOVQ	-8(SI)(BX*1), CX
	MOVQ	-8(DI)(BX*1), DX
	CMPQ	CX, DX
	SETEQ	AX
	RET

small:
	CMPQ	BX, $0
	JEQ	equal

	LEAQ	0(BX*8), CX
	NEGQ	CX

	CMPB	SI, $0xf8
	JA	si_high

	// load at SI won't cross a page boundary.
	MOVQ	(SI), SI
	JMP	si_finish
si_high:
	// address ends in 11111xxx.  Load up to bytes we want, move to correct position.
	MOVQ	-8(SI)(BX*1), SI
	SHRQ	CX, SI
si_finish:

	// same for DI.
	CMPB	DI, $0xf8
	JA	di_high
	MOVQ	(DI), DI
	JMP	di_finish
di_high:
	MOVQ	-8(DI)(BX*1), DI
	SHRQ	CX, DI
di_finish:

	SUBQ	SI, DI
	SHLQ	CX, DI
equal:
	SETEQ	AX
	RET

TEXT runtime·cmpstring(SB),NOSPLIT,$0-40
	MOVQ	s1_base+0(FP), SI
	MOVQ	s1_len+8(FP), BX
	MOVQ	s2_base+16(FP), DI
	MOVQ	s2_len+24(FP), DX
	CALL	runtime·cmpbody(SB)
	MOVQ	AX, ret+32(FP)
	RET

TEXT runtime·cmpbytes(SB),NOSPLIT,$0-56
	MOVQ	s1+0(FP), SI
	MOVQ	s1+8(FP), BX
	MOVQ	s2+24(FP), DI
	MOVQ	s2+32(FP), DX
	CALL	runtime·cmpbody(SB)
	MOVQ	AX, res+48(FP)
	RET

// input:
//   SI = a
//   DI = b
//   BX = alen
//   DX = blen
// output:
//   AX = 1/0/-1
TEXT runtime·cmpbody(SB),NOSPLIT,$0-0
	CMPQ	SI, DI
	JEQ	cmp_allsame
	CMPQ	BX, DX
	MOVQ	DX, BP
	CMOVQLT	BX, BP // BP = min(alen, blen) = # of bytes to compare
	CMPQ	BP, $8
	JB	cmp_small

cmp_loop:
	CMPQ	BP, $16
	JBE	cmp_0through16
	MOVOU	(SI), X0
	MOVOU	(DI), X1
	PCMPEQB X0, X1
	PMOVMSKB X1, AX
	XORQ	$0xffff, AX	// convert EQ to NE
	JNE	cmp_diff16	// branch if at least one byte is not equal
	ADDQ	$16, SI
	ADDQ	$16, DI
	SUBQ	$16, BP
	JMP	cmp_loop
	
	// AX = bit mask of differences
cmp_diff16:
	BSFQ	AX, BX	// index of first byte that differs
	XORQ	AX, AX
	MOVB	(SI)(BX*1), CX
	CMPB	CX, (DI)(BX*1)
	SETHI	AX
	LEAQ	-1(AX*2), AX	// convert 1/0 to +1/-1
	RET

	// 0 through 16 bytes left, alen>=8, blen>=8
cmp_0through16:
	CMPQ	BP, $8
	JBE	cmp_0through8
	MOVQ	(SI), AX
	MOVQ	(DI), CX
	CMPQ	AX, CX
	JNE	cmp_diff8
cmp_0through8:
	MOVQ	-8(SI)(BP*1), AX
	MOVQ	-8(DI)(BP*1), CX
	CMPQ	AX, CX
	JEQ	cmp_allsame

	// AX and CX contain parts of a and b that differ.
cmp_diff8:
	BSWAPQ	AX	// reverse order of bytes
	BSWAPQ	CX
	XORQ	AX, CX
	BSRQ	CX, CX	// index of highest bit difference
	SHRQ	CX, AX	// move a's bit to bottom
	ANDQ	$1, AX	// mask bit
	LEAQ	-1(AX*2), AX // 1/0 => +1/-1
	RET

	// 0-7 bytes in common
cmp_small:
	LEAQ	(BP*8), CX	// bytes left -> bits left
	NEGQ	CX		//  - bits lift (== 64 - bits left mod 64)
	JEQ	cmp_allsame

	// load bytes of a into high bytes of AX
	CMPB	SI, $0xf8
	JA	cmp_si_high
	MOVQ	(SI), SI
	JMP	cmp_si_finish
cmp_si_high:
	MOVQ	-8(SI)(BP*1), SI
	SHRQ	CX, SI
cmp_si_finish:
	SHLQ	CX, SI

	// load bytes of b in to high bytes of BX
	CMPB	DI, $0xf8
	JA	cmp_di_high
	MOVQ	(DI), DI
	JMP	cmp_di_finish
cmp_di_high:
	MOVQ	-8(DI)(BP*1), DI
	SHRQ	CX, DI
cmp_di_finish:
	SHLQ	CX, DI

	BSWAPQ	SI	// reverse order of bytes
	BSWAPQ	DI
	XORQ	SI, DI	// find bit differences
	JEQ	cmp_allsame
	BSRQ	DI, CX	// index of highest bit difference
	SHRQ	CX, SI	// move a's bit to bottom
	ANDQ	$1, SI	// mask bit
	LEAQ	-1(SI*2), AX // 1/0 => +1/-1
	RET

cmp_allsame:
	XORQ	AX, AX
	XORQ	CX, CX
	CMPQ	BX, DX
	SETGT	AX	// 1 if alen > blen
	SETEQ	CX	// 1 if alen == blen
	LEAQ	-1(CX)(AX*2), AX	// 1,0,-1 result
	RET

TEXT bytes·IndexByte(SB),NOSPLIT,$0
	MOVQ s+0(FP), SI
	MOVQ s_len+8(FP), BX
	MOVB c+24(FP), AL
	CALL runtime·indexbytebody(SB)
	MOVQ AX, ret+32(FP)
	RET

TEXT strings·IndexByte(SB),NOSPLIT,$0
	MOVQ s+0(FP), SI
	MOVQ s_len+8(FP), BX
	MOVB c+16(FP), AL
	CALL runtime·indexbytebody(SB)
	MOVQ AX, ret+24(FP)
	RET

// input:
//   SI: data
//   BX: data len
//   AL: byte sought
// output:
//   AX
TEXT runtime·indexbytebody(SB),NOSPLIT,$0
	MOVQ SI, DI

	CMPQ BX, $16
	JLT indexbyte_small

	// round up to first 16-byte boundary
	TESTQ $15, SI
	JZ aligned
	MOVQ SI, CX
	ANDQ $~15, CX
	ADDQ $16, CX

	// search the beginning
	SUBQ SI, CX
	REPN; SCASB
	JZ success

// DI is 16-byte aligned; get ready to search using SSE instructions
aligned:
	// round down to last 16-byte boundary
	MOVQ BX, R11
	ADDQ SI, R11
	ANDQ $~15, R11

	// shuffle X0 around so that each byte contains c
	MOVD AX, X0
	PUNPCKLBW X0, X0
	PUNPCKLBW X0, X0
	PSHUFL $0, X0, X0
	JMP condition

sse:
	// move the next 16-byte chunk of the buffer into X1
	MOVO (DI), X1
	// compare bytes in X0 to X1
	PCMPEQB X0, X1
	// take the top bit of each byte in X1 and put the result in DX
	PMOVMSKB X1, DX
	TESTL DX, DX
	JNZ ssesuccess
	ADDQ $16, DI

condition:
	CMPQ DI, R11
	JLT sse

	// search the end
	MOVQ SI, CX
	ADDQ BX, CX
	SUBQ R11, CX
	// if CX == 0, the zero flag will be set and we'll end up
	// returning a false success
	JZ failure
	REPN; SCASB
	JZ success

failure:
	MOVQ $-1, AX
	RET

// handle for lengths < 16
indexbyte_small:
	MOVQ BX, CX
	REPN; SCASB
	JZ success
	MOVQ $-1, AX
	RET

// we've found the chunk containing the byte
// now just figure out which specific byte it is
ssesuccess:
	// get the index of the least significant set bit
	BSFW DX, DX
	SUBQ SI, DI
	ADDQ DI, DX
	MOVQ DX, AX
	RET

success:
	SUBQ SI, DI
	SUBL $1, DI
	MOVQ DI, AX
	RET

TEXT bytes·Equal(SB),NOSPLIT,$0-49
	MOVQ	a_len+8(FP), BX
	MOVQ	b_len+32(FP), CX
	XORQ	AX, AX
	CMPQ	BX, CX
	JNE	eqret
	MOVQ	a+0(FP), SI
	MOVQ	b+24(FP), DI
	CALL	runtime·memeqbody(SB)
eqret:
	MOVB	AX, ret+48(FP)
	RET

// A Duff's device for zeroing memory.
// The compiler jumps to computed addresses within
// this routine to zero chunks of memory.  Do not
// change this code without also changing the code
// in ../../cmd/6g/ggen.c:clearfat.
// AX: zero
// DI: ptr to memory to be zeroed
// DI is updated as a side effect.
TEXT runtime·duffzero(SB), NOSPLIT, $0-0
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	STOSQ
	RET

// A Duff's device for copying memory.
// The compiler jumps to computed addresses within
// this routine to copy chunks of memory.  Source
// and destination must not overlap.  Do not
// change this code without also changing the code
// in ../../cmd/6g/cgen.c:sgen.
// SI: ptr to source memory
// DI: ptr to destination memory
// SI and DI are updated as a side effect.

// NOTE: this is equivalent to a sequence of MOVSQ but
// for some reason that is 3.5x slower than this code.
// The STOSQ above seem fine, though.
TEXT runtime·duffcopy(SB), NOSPLIT, $0-0
	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	MOVQ	(SI),CX
	ADDQ	$8,SI
	MOVQ	CX,(DI)
	ADDQ	$8,DI

	RET

TEXT runtime·fastrand1(SB), NOSPLIT, $0-4
	get_tls(CX)
	MOVQ	g(CX), AX
	MOVQ	g_m(AX), AX
	MOVL	m_fastrand(AX), DX
	ADDL	DX, DX
	MOVL	DX, BX
	XORL	$0x88888eef, DX
	CMOVLMI	BX, DX
	MOVL	DX, m_fastrand(AX)
	MOVL	DX, ret+0(FP)
	RET

TEXT runtime·return0(SB), NOSPLIT, $0
	MOVL	$0, AX
	RET


// Called from cgo wrappers, this function returns g->m->curg.stack.hi.
// Must obey the gcc calling convention.
TEXT _cgo_topofstack(SB),NOSPLIT,$0
	get_tls(CX)
	MOVQ	g(CX), AX
	MOVQ	g_m(AX), AX
	MOVQ	m_curg(AX), AX
	MOVQ	(g_stack+stack_hi)(AX), AX
	RET
