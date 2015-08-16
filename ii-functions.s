.section .data
	indexdir:
		.ascii "echo/"
		.rept 80
		.byte 0
		.endr
	msgdir:
		.ascii "msg/"
		.rept 80
		.byte 0
		.endr
	last_size:
		.long 0

.section .bss
	.lcomm stt, 88

.globl get_file_contents, get_memory, fsize, strlen, quit, getLocalEcho, getRawMsg
.type get_file_contents @function
.type get_memory @function
.type get_break @function
.type set_break @function
.type fsize @function
.type strlen @function
.type quit @function
.type getLocalEcho @function
.type getRawMsg @function

.section .text

get_break:
	movl $45, %eax
	movl $0, %ebx
	int $0x80
	ret

set_break:
	movl $45, %eax
	movl 4(%esp), %ebx
	int $0x80
	ret

get_memory:
	call get_break
	addl 4(%esp), %eax

	pushl %eax
	call set_break
	addl $4, %esp

	cmpl $0, %eax
	jl exit
	subl 4(%esp), %eax
	ret

strlen:
	movl $0, %eax
	movl 4(%esp), %ebx

	start_len:
	movb (%ebx), %ch
	cmpb $0, %ch
	je end_len
	incl %eax
	incl %ebx
	jmp start_len

	end_len:
	ret
	
fsize:
	movl $106, %eax
	movl 4(%esp), %ebx
	movl $stt, %ecx
	int $0x80

	movl 20(%ecx), %eax
	ret

get_file_contents:
	pushl %ebp
	movl %esp, %ebp

	movl $5, %eax
	movl 8(%ebp), %ebx # получаем имя файла
	movl $0, %ecx
	movl $0666, %edx
	int $0x80

	cmpl $0, %eax
	jl exit
	pushl %eax # пушим файловый дескриптор

	pushl 8(%ebp) # пушим имя файла
	call fsize
	movl %eax, last_size

	pushl %eax
	call get_memory

	movl %eax, %ecx # помещаем в ecx указатель на выделенную память
	popl %edx # помещаем в edx размер файла

	movl $3, %eax
	movl -4(%ebp), %ebx # cюда файловый дескриптор
	int $0x80

	movl $6, %eax
	int $0x80

	movl %ecx, %eax

	movl %ebp, %esp
	popl %ebp
	ret

getLocalEcho:
	pushl %ebp
	movl %esp, %ebp
	
	movl 8(%ebp), %esi # помещаем указатель на эху в esi
	movl $indexdir+5, %edi # куда + нужное смещение
	
	pushl 8(%ebp)
	call strlen # получаем размер строки эхи
	addl $4, %esp

	movl %eax, %ecx
	rep movsb # копируем строку

	pushl $indexdir
	call get_file_contents

	movl %ebp, %esp
	popl %ebp
	ret

getRawMsg:
	pushl %ebp
	movl %esp, %ebp
	
	movl 8(%ebp), %esi # помещаем указатель на msgid в esi
	movl $msgdir+4, %edi # куда + нужное смещение
	
	movl $20, %ecx
	rep movsb # копируем строку

	pushl $msgdir
	call get_file_contents

	movl %ebp, %esp
	popl %ebp
	ret

quit:
	movl $1, %eax
	movl $0, %ebx
	int $0x80
	ret
