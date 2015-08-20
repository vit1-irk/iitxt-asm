.section .data
	.equ CURLOPT_URL, 10002
	.equ CURLOPT_FOLLOWLOCATION, 52
	.equ CURLOPT_WRITEHEADER, 10029
	.equ CURLOPT_WRITEDATA, 10001
	.equ CURLOPT_POST, 47
	.equ CURLOPT_POSTFIELDS, 10015

	.type send_post @function
	.type write_data @function
	n:
		.ascii "\n"
	example:
		.ascii "my request"
.section .bss
	.lcomm curl, 4
.section .text

send_post: # char* request, char* postdata
	pushl %ebp
	movl %esp, %ebp

	call curl_easy_init
	movl %eax, curl 

	pushl 8(%ebp)
	pushl $CURLOPT_URL
	pushl curl
	call curl_easy_setopt
	addl $12, %esp

	pushl $1
	pushl $CURLOPT_POST
	pushl curl
	call curl_easy_setopt
	addl $12, %esp

	pushl $second_break # postdata
	pushl $CURLOPT_POSTFIELDS
	pushl curl
	call curl_easy_setopt
	addl $12, %esp
	
	pushl curl
	call curl_easy_perform

	cmpl $0, %eax
	jne print_err

	jmp endcurl
	print_err:
		pushl %eax
		call curl_easy_strerror
		pushl %eax
		call strlen
		movl %eax, %edx
		popl %ecx

		movl $4, %eax
		movl $2, %ebx # пишем в stderr
		int $0x80

		movl $4, %eax
		movl $1, %edx
		movl $n, %ecx # \n
		int $0x80
	
	endcurl:

	pushl curl
	call curl_easy_cleanup

	movl %ebp, %esp
	popl %ebp
	ret
