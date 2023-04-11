%ifndef __FILEHELPER_ASM__
%define __FILEHELPER_ASM__

%include "syscalls.inc"
%include "errno.inc"
%include "externals.inc"
%include "constants.inc"

section .bss

section .data

	PNG_marker dq 0x0a1a0a0d474e5089
	JFIF_marker dd 0x4649464a
	Exif_marker dd 0x66697845

section .text
	;tests if we can read and write to file or directory, if not, tries to change permissions
	global checkRWaccess ; char* name, bool tryChmod -> bool
checkRWaccess:
	push rdi
	push rsi
	mov rsi, R_OK
	or rsi, W_OK
	mov rax, SYS_ACCESS
	syscall
	pop rsi
	pop rdi
	test rax, rax
	jz .access
	cmp rax, EACCES
	je .no_access_ok
	cmp rax, ETXTBSY
	je .no_access_ok
	cmp rax, EROFS
	je .no_access_ok
	CHECK_SYSCALL 
.no_access_ok:
	test rsi, 1
	jz .no_chmod_ok
	mov rsi, S_IRUSR
	or rsi, S_IWUSR
	mov rax, SYS_CHMOD
	syscall
	test rax, rax
	jz .access
	cmp rax, EACCES
	je .no_chmod_ok
	cmp rax, EPERM
	je .no_chmod_ok
	cmp rax, EROFS
	je .no_chmod_ok
	CHECK_SYSCALL
.no_chmod_ok:
	xor rax, rax
	ret
.access:
	mov rax, 1
	ret
	
	global readfile ; char* filepath, void* buf, uint64 buflen -> uint64 numbytes
readfile:
	push r12
	push r13
	push r14
	push r15
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx

	mov rsi, O_RDONLY
	mov rax, SYS_OPEN
	syscall
	CHECK_SYSCALL
	mov r15, rax
	
	mov rdi, r15
	mov rsi, r13
	mov rdx, r14
	mov rax, SYS_READ
	syscall
	CHECK_SYSCALL
	mov r12, rax; numbytes
	
	mov rdi, r15
	mov rax, SYS_CLOSE
	syscall
	CHECK_SYSCALL
	
	mov rax, r12
	pop r15
	pop r14
	pop r13
	pop r12
	ret
	
	global writefile ;char* filepath, void* data, uint64 datalen
writefile:
	push r12
	push r13
	push r14
	push r15
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx
	
	mov rsi, O_WRONLY
	mov rax, SYS_OPEN
	syscall
	CHECK_SYSCALL
	
	mov r15, rax
	mov rdi, rax
	mov rsi, r13
	mov rdx, r14
	mov rax, SYS_WRITE                 
	syscall
	CHECK_SYSCALL
	
	mov rdi, r15
	mov rax, SYS_CLOSE
	syscall
	CHECK_SYSCALL
	
	pop r15
	pop r14
	pop r13
	pop r12
	ret

	global isimagefile; char* filename -> bool	
isimagefile:
	push rbp
	mov rbp, rsp
	sub rsp, 32
	
	mov rsi, rsp
	mov rdx, 32
	call readfile
	cmp rax, 32 ;"random" number, but what image file will be less than 32 bytes...
	jb .false
	mov rax, qword[rsp]
	cmp rax, qword[PNG_marker]
	je .true
	mov eax, dword[rsp+6]
	cmp eax, dword[JFIF_marker]
	je .true
	mov eax, dword[rsp+6]
	cmp eax, dword[Exif_marker]
	je .true
.false:
	mov rax, 0
	mov rsp, rbp
	pop rbp
	ret
.true:	
	mov rax, 1
	mov rsp, rbp
	pop rbp
	ret

	global iterate_direntries ; char* dir, void(*callback)(dirent64_t*)
iterate_direntries:
	push rbx
	push r12;fd
	push r13;callback
	push r14;read len
	push r15
	push rbp
	mov rbp, rsp
	sub rsp, 1024
	mov r12, rdi
	mov r13, rsi
	
	mov rsi, O_RDONLY
	or rsi, O_DIRECTORY
	mov rax, SYS_OPEN
	syscall
	CHECK_SYSCALL
	mov r12, rax
.continue_getdents:
	mov rdi, r12
	mov rsi, rsp
	mov rdx, rbp
	sub rdx, rsp;count
	mov rax, SYS_GETDENTS64
	syscall
	cmp rax, EINVAL ;too small buffer
	jne .buff_success
	sub rsp, 1024
	jmp .continue_getdents
.buff_success:
	CHECK_SYSCALL
	cmp rax, 0
	je .done_getdents ;eof
	mov r14, rax
	
	mov r15, 0; dirent64_t* offset
.loopentries:
	mov rbx, rsp
	add rbx, r15
	mov rdi, rbx
	call r13
	movzx rax, word[rbx+dirent64_t.d_reclen]
	add r15, rax
	cmp r15, r14 ;below readlen
	jb .loopentries
	jmp .continue_getdents
.done_getdents:
	mov rdi, r12
	mov rax, SYS_CLOSE
	syscall
	CHECK_SYSCALL
	
	mov rsp, rbp
	pop rbp
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	ret

%endif
	
	
