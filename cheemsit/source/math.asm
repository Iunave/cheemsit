%ifndef __MATH_ASM__
%define __MATH_ASM__

section .text
	
	global abs_flt64
abs_flt64:
	vpcmpeqq ymm1, ymm1
	vpsrlq ymm1, 1
	vpand ymm0, ymm1
	ret

	global abs_flt32
abs_flt32:
	vpcmpeqq ymm1, ymm1
	vpsrld ymm1, 1
	vpand ymm0, ymm1
	ret
	
	global abs_int64
abs_int64:
	mov rax, rdi
	neg rdi
	test rax, rax
	cmovs rax, rdi
	ret
	
	global randnormal; -> float64 (0 to 1)
randnormal:
	rdrand rax
	jnc randnormal
	mov rdi, 0x7FFFFFFFFFFFFFFF
	and rax, rdi
	vcvtsi2sd xmm0, rax
	vcvtsi2sd xmm1, rdi
	vdivsd xmm0, xmm1
	ret

	global randrange_flt ; float64, float64 -> float64
randrange_flt:
	vmovsd xmm2, xmm0
	vmovsd xmm3, xmm1
	call randnormal
	vsubsd xmm3, xmm2
	vfmadd132sd xmm0, xmm2, xmm3
	ret
	
	global randrange_int ; int64, int64 -> int64
randrange_int:
	vcvtsi2sd xmm2, rdi
	vcvtsi2sd xmm3, rsi
	call randnormal
	vsubsd xmm3, xmm2
	vfmadd132sd xmm0, xmm2, xmm3
	vcvtsd2si rax, xmm0
	ret
%endif	
