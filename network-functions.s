.section .data
	.equ CURLOPT_URL, 10002
	.equ CURLOPT_FOLLOWLOCATION, 52
	.equ CURLOPT_WRITEHEADER, 10029
	.equ CURLOPT_WRITEDATA, 10001
	.equ CURLOPT_HTTPPOST, 10024
	.equ CURLOPT_POSTFIELDS, 10015
	.equ CURLFORM_COPYCONTENTS, 4
	.equ CURLFORM_COPYNAME, 1
	.equ CURLFORM_END, 17

	.type send_post @function
	.type send_raw_post @function
	.type write_data @function
	.type lentoascii @function
	n:
		.ascii "\n"
	rn1:
		.ascii "\r\n"
	rn2:
		.ascii "\r\n\r\n"
	example:
		.ascii "my request"
	addrspec:
		
	sockfd:
		.long 0

.section .bss
	.lcomm curl, 4
	.lcomm last_httppost, 4
	.lcomm post_httppost, 4
.section .text

lentoascii:
	movl 4(%esp), %eax
	movl $10, %ecx
	movl $10, %esi
	movl $0, %edx
	movl $request_0+req0_len, %ebx

	convert:
		divl %esi # делим eax на 10
		movb %dl, (%ebx)
		movl $0, %edx
		addb $0x30, (%ebx)
		decl %ebx
	loop convert
	ret

send_raw_post:
	pushl $0
	pushl $1
	pushl $2
	call socket
	movl %eax, sockfd
	addl $12, %esp

	pushl $16
	pushl $addrspec
	pushl sockfd
	call connect
	addl $12, %esp
	
	pushl full_size
	call lentoascii
	addl $4, %esp

	movl $4, %eax
	movl sockfd, %ebx
	movl request_0, %ecx
	movl $req0_len, %edx
	int $0x80

	movl $4, %eax
	movl sockfd, %ebx
	movl second_break, %ecx
	movl full_size, %edx
	int $0x80

	movl $6, %eax
	movl sockfd, %ebx
	int $0x80

	ret

send_post: # char* request, char* postdata
	pushl %ebp
	movl %esp, %ebp

	call curl_easy_init
	movl %eax, curl 

	/*pushl 12(%ebp) # postdata
	pushl $CURLOPT_POSTFIELDS
	pushl curl
	call curl_easy_setopt
	addl $12, %esp
	*/
	pushl 8(%ebp)
	pushl $CURLOPT_URL
	pushl curl
	call curl_easy_setopt
	addl $12, %esp
	/*
	pushl $CURLFORM_END
	pushl b64_pointer
	pushl $CURLFORM_COPYCONTENTS
	pushl $tmsg
	pushl $CURLFORM_COPYNAME
	pushl $last_httppost
	pushl $post_httppost

	call curl_formadd
	addl $28, %esp

	pushl $CURLFORM_END
	pushl $authstr
	pushl $CURLFORM_COPYCONTENTS
	pushl $pauth
	pushl $CURLFORM_COPYNAME
	pushl $last_httppost
	pushl $post_httppost

	call curl_formadd
	addl $28, %esp
	
	pushl $post_httppost
	pushl $CURLOPT_HTTPPOST
	pushl curl
	call curl_easy_setopt
	addl $12, %esp
*/
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
