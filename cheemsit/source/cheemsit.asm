%include "syscalls.inc"
%include "errno.inc"
%include "externals.inc"
%include "constants.inc"

;todo disable text wrapping in terminal
;text wrapping destroys our formatting =/

section .bss
	
section .data
	
	cheems_data:
	incbin "../content/cheems.png"
	cheems_size equ $-cheems_data
	
	option_recursive db 0
	option_force db 0
	option_quiet db 0
	option_simulate db 0
	
	ignoredir1 db ".", 0
	ignoredir2 db "..", 0
	slash db "/", 0
	nullterm db 0
	
	dirmapping: istruc mmapping_t
		at mmapping_t.m_addr, dq 0
		at mmapping_t.m_len, dq 0
		at mmapping_t.m_usedlen, dq 0
	iend
	
	MMAP_SIZE_STEP equ 10240
	
	scan_str db "scanning directory: ", 0
	cheemsed_str db "cheemsedit! ", 0
	
	scanneddirs_count dq 0
	scannedfiles_count dq 0
	cheemsedfiles_count dq 0
	
	scanneddirs_str db "scanned directories: ", 0
	scannedfiles_str db "scanned files: ", 0
	cheemsedfiles_str db "cheemsed files: ", 0
	
	
section .text

	global print_info
print_info:
	test byte[option_quiet], 1
	jnz .quiet
	call print_newline
	
	mov rdi, scanneddirs_str
	call printstring
	mov rdi, qword[scanneddirs_count]
	call printint_lf
	
	mov rdi, scannedfiles_str
	call printstring
	mov rdi, qword[scannedfiles_count]
	call printint_lf
	
	mov rdi, cheemsedfiles_str
	call printstring
	mov rdi, qword[cheemsedfiles_count]
	call printint_lf
.quiet:
	ret

	global append_dirmapping ; byte* source, uint64 bytes
append_dirmapping:
	mov rcx, rsi;count
	mov rsi, rdi
	mov rdx, rcx
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	add rdi, qword[dirmapping+mmapping_t.m_usedlen]
	mov r8, rdi
	add r8, rdx ;last byte+1
	mov r9, qword[dirmapping+mmapping_t.m_addr]
	add r9, qword[dirmapping+mmapping_t.m_len];last available byte+1
	cmp r8, r9
	jna .skip_remap
	
	push rdx
	push rsi
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	mov rsi, qword[dirmapping+mmapping_t.m_len]
	add qword[dirmapping+mmapping_t.m_len], MMAP_SIZE_STEP
	mov rdx, qword[dirmapping+mmapping_t.m_len]
	call mremap
	mov qword[dirmapping+mmapping_t.m_addr], rax
	mov rdi, rax
	add rdi, qword[dirmapping+mmapping_t.m_usedlen]
	pop rsi
	pop rdx
.skip_remap:
	add qword[dirmapping+mmapping_t.m_usedlen], rdx
	jmp memcpy

	global advance_dir ; -> true if we could advance to the next directory or false if there are no more available
advance_dir:
	inc qword[scanneddirs_count];info
	
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	call strlen
	inc rax
	sub qword[dirmapping+mmapping_t.m_usedlen], rax
	mov rdx, qword[dirmapping+mmapping_t.m_usedlen]
	test rdx, rdx
	jz .lastdir
	
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	mov rsi, rdi
	add rsi, rax
	call memcpy
	
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	mov rax, SYS_CHDIR
	syscall
	CHECK_SYSCALL
	mov rax, 1
	ret
.lastdir:
	mov rax, 0
	ret

	global overwrite_file ;char* name
overwrite_file:
	push r12
	mov r12, rdi
	inc qword[cheemsedfiles_count];info
	
	test byte[option_quiet], 1
	jnz .quiet
	call print_clearline
	mov rdi, cheemsed_str
	call printstring
	mov rdi, r12
	call printstring
	call print_newline
	
	mov rdi, scan_str
	call printstring
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	call printstring
.quiet:
	test byte[option_simulate], 1
	jnz .simulate
	;overwrite
.simulate:
	pop r12
	ret
	 
	global add_dir ;char* name /null
add_dir:
	push r12
	push rbp
	mov rbp, rsp
	mov r12, rdi
.retry_getcwd:
	sub rsp, 256
	mov rdi, rsp
	mov rsi, rbp
	sub rsi, rsp
	mov rax, SYS_GETCWD
	syscall
	cmp rax, -34 ;ERANGE
	je .retry_getcwd
	CHECK_SYSCALL
	; add cwd
	mov rdi, rsp
	call strlen
	mov rdi, rsp
	mov rsi, rax
	call append_dirmapping
	mov rsp, rbp ;dealloc
	;add "/"
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	add rdi, qword[dirmapping+mmapping_t.m_usedlen]
	cmp byte[rdi-1], "/"
	je .has_trailing_slash
	mov rdi, slash
	mov rsi, 1
	call append_dirmapping
.has_trailing_slash:
	test r12, r12
	jz .add_nullterm
	; add new directory
	mov rdi, r12
	call strlen
	mov rdi, r12
	mov rsi, rax	
	call append_dirmapping 
.add_nullterm:
	mov rdi, nullterm
	mov rsi, 1
	call append_dirmapping
.finished:
	mov rsp, rbp
	pop rbp
	pop r12
	ret
	
	global direntry_callback
direntry_callback:
	mov al, byte[rdi+dirent64_t.d_type]
	cmp al, DT_REG
	je .regular
	cmp al, DT_DIR
	je .directory
	ret
.regular:
	push rbx;dirent*
	mov rbx, rdi
	inc qword[scannedfiles_count];info
	lea rdi, [rbx+dirent64_t.d_name]
	mov sil, byte[option_force]
	call checkRWaccess
	test al, 1
	jz .skip_reg
	
	lea rdi, [rbx+dirent64_t.d_name]
	call isimagefile
	test al, 1
	jz .skip_reg
	
	lea rdi, [rbx+dirent64_t.d_name]
	call overwrite_file
.skip_reg:
	pop rbx
	ret
.directory:
	push rbx;dirent*
	push r12
	mov rbx, rdi
	
	test byte[option_recursive], 1
	jz .skip_dir
	
	lea rdi, [rbx+dirent64_t.d_name]
	call strlen
	mov r12, rax
	
	lea rdi, [rbx+dirent64_t.d_name]
	mov rsi, ignoredir1
	mov rdx, r12
	call memcmpb
	test al, 1
	jnz .skip_dir
	
	lea rdi, [rbx+dirent64_t.d_name]
	mov rsi, ignoredir2
	mov rdx, r12
	call memcmpb
	test al, 1
	jnz .skip_dir
	
	lea rdi, [rbx+dirent64_t.d_name]
	call add_dir
.skip_dir:
	pop r12
	pop rbx
	ret
	
	global scan_dir
scan_dir:	
	test byte[option_quiet], 1
	jnz .quiet
	call print_clearline
	mov rdi, scan_str
	call printstring
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	call printstring
.quiet:
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	mov rsi, direntry_callback
	jmp iterate_direntries
	
	global _start
_start:
	pop rcx;argc
	dec rcx
	pop rbx;ignore name
	test rcx, rcx
	jz .arg_complete
.next_arg:
	pop rbx
	cmp byte[rbx], '-'
	jne .startdir_arg
	
	cmp byte[rbx+1], 'r'
	sete al
	or byte[option_recursive], al
	cmp byte[rbx+1], 'f'
	sete al
	or byte[option_force], al
	cmp byte[rbx+1], 'q'
	sete al
	or byte[option_quiet], al
	cmp byte[rbx+1], 's'
	sete al
	or byte[option_simulate], al
	
	loop .next_arg
	jmp .arg_complete
.startdir_arg:
	push rcx
	mov rdi, rbx
	mov rax, SYS_CHDIR
	syscall
	CHECK_SYSCALL
	pop rcx
	loop .next_arg
.arg_complete:
	mov rdi, MMAP_SIZE_STEP
	mov qword[dirmapping+mmapping_t.m_len], rdi
	call mmap
	mov qword[dirmapping+mmapping_t.m_addr], rax
	
	mov rdi, 0
	call add_dir
	
.loopdirs:
	call scan_dir
	call advance_dir
	test al, 1
	jnz .loopdirs
	
	mov rdi, qword[dirmapping+mmapping_t.m_addr]
	mov rsi, qword[dirmapping+mmapping_t.m_len]
	call munmap
	
	test byte[option_quiet], 1
	jnz .quiet
	call print_clearline
	call print_info
.quiet:
	mov rdi, 0
	mov rax, SYS_EXIT
	syscall
