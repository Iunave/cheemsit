#!/bin/bash

red='\e[1;31m%s\e[0m'
green='\e[1;32m%s\e[0m'
yellow='\e[1;33m%s\e[0m'
blue='\e[1;34m%s\e[0m'
magenta='\e[1;35m%s\e[0m'
cyan='\e[1;36m%s\e[0m'

function echobuild()
{
	printf "$blue\n" "[build] $1"
}

function echoinfo()
{
	printf "$cyan\n" "[info] $1"
}

function echosuccess()
{
	printf "$green\n" "[success] $1"
}

function echowarn() 
{
	printf "$yellow\n" "[warning] $1"
}

function echoerr() 
{
	printf "$red\n" "[error] $1" >> /dev/stderr
}

function execcommand()
{
	echobuild "$1"
	$1
}

[ -d "build" ] || execcommand "mkdir build"
[ -d "build/bin" ] || execcommand "mkdir build/bin"
[ -d "source" ] || execcommand "mkdir source"

src_files=()
wants_help=0
wants_clean=0
wants_run=0
program_args=()
build_mode=""
output_name="exec"

argv=($@)
 
for ((i=0; i < $#; i++))
do

	arg=${argv[$i]}
	
	if [[ $wants_run -eq 1 ]]
	then
		program_args+=($arg)
		continue
	fi
	
	case "${arg,,}" in
	
	"-help")
		wants_help=1
	;;
	"-clean")
		wants_clean=1
	;;
	"-debug")
		build_mode="debug"
	;;
	"-release")
		build_mode="release"
	;;
	"-run")
		wants_run=1
	;;
	"-o")
		((i+=1))
		if [[ $i == $# ]]
		then
			echoerr "no name specified for -o"
			exit -1
		fi
		output_name="${argv[$i]}"
	;;
	"-"*)
		echoerr "unrecognized option: $arg"
		exit -1
	;;
	*)
		src_files+=($arg)
	;;
	
	esac
done

if  [[ $wants_help -eq 1 ]]
then
	echo "build.sh: assemble, link and optionally run the generated program"
	echo "all arguments not prefixed with \"-\" are treated as source files"
	echo "the source files must be located in the \"source\" directory relative to this script"
	echo "if no source files are specified all files postfixed with \".asm\" in \"source\" will be chosen"
	echo "build files are written to the \"build\" directory"
	echo
	echo -e "-help\011displays this information and exits"
	echo -e "-clean\011remove all files in the build directory and exits"
	echo -e "-run <args>\011runs the program after a successfull build with <args>"
	echo -e "-debug (default)\011\011assemble and link with debug information"
	echo -e "-release\011\011assemble and link with no debug information and strip files"
	echo -e "-o <name> (default=exec)\011\011output file name"
	

	echo -e "(args) (start file directory) directory to search, eg: ~ \n-r (recusive) descends into subdirectories \n-q (quiet) no text output\n-f (force) attempts to change file permissions if needed\n-s (simulate) does not actually replace any files, but may still change file permissions if -f is enabled (does nothing in this build as the code that replaces the files is removed for safety reasons)"
	echo -e "\nexample: ./build.sh -debug -run ~ -r -q -f -s"
	exit 0
fi

if [[ $wants_clean -eq 1 ]]
then
	execcommand "rm -r --verbose build/*"
	exit 0
fi

if [[ -z $build_mode ]]
then
	build_mode="debug"
	echowarn "no build mode specified... defaulting to debug"
fi


if [ ${#src_files[@]} -eq 0 ]
then
	echoinfo "no input files specified... searching $(pwd)/source"
	src_files=($(ls source | grep ".asm"))
	
	if [ ${#src_files[@]} -eq 0 ]
	then 
		echoerr "no files found"
		exit -1
	else
		for file in ${src_files[*]}
		do	
			echoinfo "found $file"
		done
	fi
else
	for file in ${src_files[*]}
	do	
		if [[ ! -f "source/$file" ]]
		then
			echoerr "$file does not exist in source directory"
			exit -1
		fi
	done
fi

src_files=( ${src_files[@]%.asm} ) 

assembler_err=0
linker_err=0

for file in ${src_files[*]}
do
	assembler_cmd=""

	if [[ $build_mode == "debug" ]]
	then 
		assembler_cmd="nasm -g -F dwarf -f elf64 -dDEBUG=1 -isource/ -o build/$file.o -Lm -l build/$file.lst source/$file.asm"

	elif [[ $build_mode == "release" ]] 
	then
		assembler_cmd="nasm -f elf64 -dRELEASE=1 -isource/ -o build/$file.o source/$file.asm"
	fi

	execcommand "$assembler_cmd"
	[[ $? -eq 0 ]] || assembler_err=1
done

if [[ $assembler_err -ne 0 ]]
then
	echoerr "one or more files failed to assemble"
	exit -1
fi

obj_files=( ${src_files[@]/%/.o} )
obj_files=( ${obj_files[@]/#/build/} )

link_cmd=""

if [[ $build_mode == "debug" ]]
then 
	link_cmd="ld -g -o build/bin/$output_name ${obj_files[*]}"

elif [[ $build_mode == "release" ]] 
then
	link_cmd="ld -O --strip-all -o build/bin/$output_name ${obj_files[*]}"
fi

execcommand "$link_cmd"
[[ $? -eq 0 ]] || linker_err=1

if [[ $linker_err -eq 0 ]]
then
	echosuccess "build files written to $(pwd)/build"
	echoinfo "program size: $(wc -c build/bin/$output_name)"

	if [[ $wants_run -eq 1 ]]
	then	
		cd "build/bin" || exit 1
		command="./$output_name ${program_args[*]}"
		
		echoinfo "running $command"
		printf %"$COLUMNS"s | tr " " "-"
		echo
		
		start_time=$EPOCHREALTIME
		
		tput rmam #fixes formatting
		
		$command
		exit_code=$?
		
		tput smam
		
		end_time=$EPOCHREALTIME
		delta_time=$(bc -l <<< "$end_time - $start_time")
		
		printf %"$COLUMNS"s | tr " " "-"
		echoinfo "exit code: $exit_code"
		echoinfo "total time in execution: $delta_time"	
	fi
else
	echoerr "linker failed"
fi

exit 0
