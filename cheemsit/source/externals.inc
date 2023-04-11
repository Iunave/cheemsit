%ifndef __EXTERNALS_INC__
%define __EXTERNALS_INC__

%ifndef __FILEHELPER_ASM__
extern checkRWaccess
extern readfile
extern writefile
extern isimagefile
extern iterate_direntries
%endif

%ifndef __MATH_ASM__
extern abs_flt64
extern abs_flt32
extern abs_int64
extern randnormal
extern randrange_flt
extern randrange_int
%endif

%ifndef __MEMORY_ASM__
extern memcpy
extern memcmpb
extern memcmpq
extern mmap
extern mremap
extern munmap
%endif

%ifndef __STRINGMANIP_ASM__
extern strlen
extern stringcmp 
extern printstring 
extern printstring_lf
extern printstring_overwrite
extern printint 
extern printint_lf
extern print_clearline
extern print_newline
extern print_savecursor
extern print_restorecursor
extern inttostring 
extern stringtoint 
extern stringshuffle
extern findchar
extern removechars
extern removespaces
extern replacechars
extern readstdinline
%endif

%endif
