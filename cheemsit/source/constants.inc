%ifndef __CONSTANTS_INC__
%define __CONSTANTS_INC__

NULL equ 0
LF equ 10
STDIN equ 0
STDOUT equ 1
STDERR equ 2
O_RDONLY equ 000000q
O_WRONLY equ 000001q
O_RDWR equ 000002q
O_DIRECTORY equ 0200000q

DT_UNKNOWN equ 0
DT_FIFO equ 1
DT_CHR equ 2
DT_DIR equ 4
DT_BLK equ 6
DT_REG equ 8
DT_LNK equ 10
DT_SOCK equ 12
DT_WHT equ 14

W_OK equ 2
R_OK equ 4

S_IRUSR equ 0400q	;Read by owner. 
S_IWUSR equ 0200q	;Write by owner.  
S_IEUSR	equ 0100q	;Execute by owner. 

ASCII_ESC equ 27
ASCII_CR equ 13
ASCII_SUB equ 26
ASCII_LF equ 10

%macro PUSHSD 1
	sub rsp, 8
	vmovsd qword[rsp], %1
%endmacro

%macro POPSD 1
	vmovsd %1, qword[rsp]
	add rsp, 8
%endmacro

%macro PRINT 1
	[section .data]
	%%msg: db %1, LF, 0
	__SECT__
	mov rdi, %%msg
	call printstring
%endmacro

%macro ABORT 0-1 "unspecified error, aborting"
%ifdef DEBUG
		call print_newline
	%ifstr %1
		PRINT %1
	%else
		mov rdi, %1
		call printstring
	%endif
		call print_newline
%endif
	mov rax, SYS_GETPID
	syscall
	mov rdi, rax
	mov rsi, 6 ;abort
	mov rax, SYS_KILL
	syscall
%endmacro

%macro CHECK 1-2 "unspecified error, aborting"
	j%-1 %%skip
	ABORT %2
%%skip:
%endmacro

	struc dirent64_t
	.d_ino    resq 1 ;64-bit inode number
	.d_off    resq 1 ;64-bit offset to next structure 
	.d_reclen resw 1 ;Size of this dirent 
	.d_type   resb 1 ;File type 
	.d_name   resb 1 ;Filename (null-terminated) (in place)
	endstruc
	
	struc timespec_t
	.tv_sec resq 1
	.tv_nsec resq 1
	endstruc
	
	struc mmapping_t
	.m_addr resq 1
	.m_len resq 1
	.m_usedlen resq 1
	endstruc

%endif ;__CONSTANTS_INC__
