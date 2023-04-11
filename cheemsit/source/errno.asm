%ifndef __ERRNO_ASM__
%define __ERRNO_ASM__

%include "syscalls.inc"

	section .data
%ifdef DEBUG
	align 64
	errno_strtbl:
%endif

%include "errno.inc"

extern printstring
extern print_newline
	
section .text

	global check_syscall_fail
check_syscall_fail:
%ifdef DEBUG
	neg rax
	dec rax
	shl rax, 6 ;*64
	lea rbx, [errno_strtbl+rax]
	call print_newline
	mov rdi, rbx
	call printstring
	call print_newline
%endif
	mov rax, SYS_GETPID
	syscall
	mov rdi, rax
	mov rsi, 6 ;abort
	mov rax, SYS_KILL
	syscall
%endif
