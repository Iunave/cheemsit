%ifndef __STRINGMANIP_ASM__
%define __STRINGMANIP_ASM__

%include "syscalls.inc"
%include "errno.inc"
%include "constants.inc"
%include "externals.inc"

INPUT_BUFFER_SIZE equ 256
common inputbuffer 256:1
	
section .data

	newline_str db ASCII_LF, 0
	clearline_str db ASCII_CR, ASCII_ESC, "[K", 0
	savecursor_str db ASCII_ESC, "[s", 0
	restorecursor_str db ASCII_ESC, "[u", 0

section .text

	global strlen ;char* -> int64
strlen:
	mov rsi, rdi
	vxorpd ymm0, ymm0
.loop:
	vmovdqu ymm1, [rdi]
	add rdi, 32
	vpcmpeqb ymm1, ymm0
	vpmovmskb edx, ymm1
	test edx, edx
	jz .loop
	
	bsf edx, edx
	mov rax, 32
	sub rax, rdx
	sub rdi, rax
	sub rdi, rsi
	mov rax, rdi
	ret

	global stringcmp ;char*, char*, uint64 -> bool
stringcmp:
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
	
	global printstring ;(char*)
printstring:
	push rdi
	call strlen
	pop rsi
	mov rdx, rax
	mov rax, SYS_WRITE
	mov rdi, STDOUT
	syscall
	CHECK_SYSCALL
	ret
	
	global printstring_lf ;(char*)
printstring_lf:
	call printstring
	mov rdi, newline_str
	jmp printstring
	
	global print_newline
print_newline:
	mov rdi, newline_str
	jmp printstring
	
	global print_clearline
print_clearline:
	mov rdi, clearline_str
	jmp printstring
	
	global print_savecursor
print_savecursor:
	mov rdi, savecursor_str
	jmp printstring
	
	global print_restorecursor
print_restorecursor:
	mov rdi, restorecursor_str
	jmp printstring
	
	global printstring_overwrite
printstring_overwrite:
	push rdi
	mov rdi, clearline_str
	call printstring
	pop rdi
	jmp printstring
	
	global printint ;(int64)
printint:
	push rbp
	mov rbp, rsp	
	sub rsp, 64 ;allocate 64 bytes for the string
	lea rsi, [rbp-64]
	call inttostring
	lea rdi, [rbp-64]
	call printstring
	mov rsp, rbp
	pop rbp
	ret
	
	global printint_lf ;(int64)
printint_lf:
	push rbp
	mov rbp, rsp	
	sub rsp, 64 ;allocate 64 bytes for the string
	lea rsi, [rbp-64]
	call inttostring
	lea rdi, [rbp-64]
	call printstring_lf
	mov rsp, rbp
	pop rbp
	ret
	
	global inttostring ;int64, char*
inttostring:
	mov r8, '+'
	mov r9, '-'
	mov r10, rdi
	neg r10
	test rdi, rdi
	cmovs r8, r9
	cmovs rdi, r10
	mov byte[rsi], r8b
	inc rsi
	
	mov rcx, 0; digit count
	mov r8, 10; divider
	mov rax, rdi  
.div_loop:
	inc rcx
	cqo
	idiv r8
	sub rsp, 1;allocate 1 byte on stack
	mov byte[rsp], dl
	cmp rax, 0
	jne .div_loop
	
	mov r8, 0
.pop_loop:
	mov al, byte[rsp]
	add rsp, 1
	add al, '0'
	mov byte[rsi+r8], al
	inc r8
	cmp r8, rcx
	jb .pop_loop
	
	mov byte[rsi+r8], 0
	ret
	
	global stringtoint ;(string) -> rax
stringtoint:
	push rdi
	call strlen
	pop rdi
	
	mov rcx, rax
	mov rax, 0
	mov r10, 1
.mul_loop:
	cmp rcx, 0
	je .done
	dec rcx
	movzx r8, byte[rdi+rcx]
	cmp r8b, '+'
	je .done
	cmp r8b, '-'
	je .minus
	cmp r8b, '0'
	jb .invchar
	cmp r8b, '9'
	ja .invchar

	sub r8, '0'
	imul r8, r10
	add rax, r8
	jo .overflow
	imul r10, 10
	jmp .mul_loop
.minus:
	neg rax
.done:
	ret
.overflow:
	ABORT "stoi overflow"
.invchar:
	ABORT "stoi invalid character"
	
	global stringshuffle ;char*
stringshuffle:
	push rbx
	push r12
	push r13
	push r14
	push r15
	mov r12, rdi
	call strlen
	dec rax
	cmp rax, 0
	jle .finished
	mov rbx, rax
	mov r13, rax
.loop:
	mov rdi, 0
	mov rsi, r13
	call randrange_int
	lea r14, [r12+rax]
	
	mov rdi, 0
	mov rsi, r13
	call randrange_int
	lea r15, [r12+rax]

	mov al, byte[r14]
	mov dl, byte[r15]
	mov byte[r14], dl
	mov byte[r15], al

	dec rbx
	test rbx, rbx
	jnz .loop
.finished:
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	ret
	
	global findchar; char*, char -> char*
findchar:
	lea rax, [rdi-1]
.loop:
	inc rax
	mov r10b, byte[rax]
	cmp r10b, 0
	je .not_found
	cmp r10b, sil
	jne .loop
	ret
.not_found:
	xor rax, rax
	ret
	
	global removechars ; char* in, char* out, char
removechars:
	mov al, byte[rdi]
	inc rdi
	cmp al, dl
	je removechars
	mov byte[rsi], al
	inc rsi
	cmp al, 0
	jne removechars
	ret
	
	global removespaces ; char* in, char* out
removespaces:
	mov dl, ' '
	jmp removechars
	
	global replacechars ; char* source, char match, char replacement
replacechars:
	dec rdi
.loop:
	inc rdi
	mov al, byte[rdi]
	test al, al
	jz .done
	cmp al, sil
	cmove eax, edx
	mov byte[rdi], al
	jmp .loop
.done:
	ret
	
	global readstdinline ; char* buf, unint64 len
readstdinline:
	push rbx
	push r12
	push r13
	mov rbx, -1; count
	mov r12, rdi
	mov r13, rsi
	
.readchar:
	inc rbx
	cmp rbx, r13
	jae .bufsize_exceeded
	
	mov rax, SYS_READ
	mov rdi, STDIN
	lea rsi, [r12+rbx]
	mov rdx, 1
	syscall
	
	cmp byte[r12+rbx], LF
	jne .readchar

	mov byte[r12+rbx], NULL
	
	pop r13
	pop r12
	pop rbx
	ret
	
.bufsize_exceeded:
	ABORT "input buffer exceeded"
	
	global get_readstdinline
get_readstdinline:
	mov rdi, inputbuffer
	mov rsi, INPUT_BUFFER_SIZE
	call readstdinline
	mov rax, inputbuffer
	ret
	
%endif
	
	
