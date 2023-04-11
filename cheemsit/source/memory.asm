%ifndef __MEMORY_ASM__
%define __MEMORY_ASM__

%include "syscalls.inc"
%include "errno.inc"
%include "externals.inc"
%include "constants.inc"	

PROT_READ equ 0x1
PROT_WRITE equ 0x2
MAP_ANONYMOUS equ 0x20
MAP_PRIVATE equ 0x2
MAP_SHARED equ 0x01
REMAP_MAYMOVE equ 1

section .text

	global memcpy ; void* dest, void* source, uint64 bytes
memcpy:
    cld
.loop_ymm_16:
    test rdx, -512
    jz .loop_ymm_1
    vmovdqu ymm0, yword[rsi + 32*0]
    vmovdqu yword[rdi + 32*0], ymm0
    vmovdqu ymm1, yword[rsi + 32*1]
    vmovdqu yword[rdi + 32*1], ymm1
    vmovdqu ymm2, yword[rsi + 32*2]
    vmovdqu yword[rdi + 32*2], ymm2
    vmovdqu ymm3, yword[rsi + 32*3]
    vmovdqu yword[rdi + 32*3], ymm3
    vmovdqu ymm4, yword[rsi + 32*4]
    vmovdqu yword[rdi + 32*4], ymm4
    vmovdqu ymm5, yword[rsi + 32*5]
    vmovdqu yword[rdi + 32*5], ymm5
    vmovdqu ymm6, yword[rsi + 32*6]
    vmovdqu yword[rdi + 32*6], ymm6
    vmovdqu ymm7, yword[rsi + 32*7]
    vmovdqu yword[rdi + 32*7], ymm7
    vmovdqu ymm8, yword[rsi + 32*8]
    vmovdqu yword[rdi + 32*8], ymm8
    vmovdqu ymm9, yword[rsi + 32*9]
    vmovdqu yword[rdi + 32*9], ymm9
    vmovdqu ymm10, yword[rsi + 32*10]
    vmovdqu yword[rdi + 32*10], ymm10
    vmovdqu ymm11, yword[rsi + 32*11]
    vmovdqu yword[rdi + 32*11], ymm11
    vmovdqu ymm12, yword[rsi + 32*12]
    vmovdqu yword[rdi + 32*12], ymm12
    vmovdqu ymm13, yword[rsi + 32*13]
    vmovdqu yword[rdi + 32*13], ymm13
    vmovdqu ymm14, yword[rsi + 32*14]
    vmovdqu yword[rdi + 32*14], ymm14
    vmovdqu ymm15, yword[rsi + 32*15]
    vmovdqu yword[rdi + 32*15], ymm15
    add rdi, 512
    add rsi, 512
    sub rdx, 512
    jmp .loop_ymm_16
.loop_ymm_1:
    test rdx, -32
    jz .loop_q
    vmovdqu ymm0, yword[rsi]
    vmovdqu yword[rdi], ymm0
    add rdi, 32
    add rsi, 32
    sub rdx, 32
    jmp .loop_ymm_1
.loop_q:
    test rdx, -8
    jz .loop_b
    movsq
    sub rdx, 8
    jmp .loop_q
.loop_b:
    dec rdx
    js .finished
    movsb
    jmp .loop_b
.finished:
    ret

	global memcmpb ; byte* a, byte* b, uint64 bytes -> bool
memcmpb:
	cld
.loop:
	dec rdx
	js .equal
	cmpsb
	je .loop
	xor rax, rax
	ret
.equal:
	mov rax, 1
	ret
	
	global memcmpq ; qword* a, qword* b, uint64 bytes -> bool
memcmpq:
	cld
.loop:
	sub rdx, 8
	js .equal
	cmpsq
	je .loop
	xor rax, rax
	ret
.equal:
	mov rax, 1
	ret

	global mmap ;uint64 size -> void* 
mmap:
	mov rsi, rdi ;len
	mov rdi, 0 ;addr
	mov rdx, PROT_READ
	or rdx, PROT_WRITE
	mov r10, MAP_ANONYMOUS
	or r10, MAP_PRIVATE
	mov r8, -1 ; fd
	mov r9, 0 ; offset
	mov rax, SYS_MMAP
	syscall
	CHECK_SYSCALL
	ret
	
	global mremap ;void* addr, u64 oldsize, uint64 newsize -> void*
mremap:
	mov r10, REMAP_MAYMOVE
	mov rax, SYS_MREMAP
	syscall
	CHECK_SYSCALL
	ret

	global munmap ;void addr, u64 len -> int
munmap:
	mov rax, SYS_MUNMAP
	syscall
	CHECK_SYSCALL
	ret
	
%endif
