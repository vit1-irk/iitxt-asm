.include "ii-functions.s"
.section .data
	usage_str:
		.ascii "Usage: view <echoarea>\n"
	n:
		.ascii "\n\n"
	echo_filedata:
		.long 0
	msg_filedata:
		.long 0

.globl main
.section .text

main:
	movl 8(%esp), %eax
	cmpl $1, 4(%esp) # смотрим, сколько аргументов командной строки
	jle usage # если их нет, то печатаем usage_str и выходим
	
	pushl 4(%eax) # получаем указатель на первый символ аргумента
	call getLocalEcho

	movl %eax, echo_filedata
	addl $4, %esp
	
	printing_messages:

	pushl echo_filedata
	call getRawMsg
	movl %eax, %ecx # помещаем указатель на строку в буфер для вывода на экран
	addl $4, %esp

	movl $4, %eax # выводим инфу
	movl $1, %ebx # в stdout
	movl last_size, %edx # размер файла
	int $0x80

	movl $4, %eax
	movl $1, %ebx
	movl $n, %ecx
	movl $2, %edx
	int $0x80

	addl $21, echo_filedata # переходим к следующему msgid
	movl echo_filedata, %edi
	cmpl $0, (%edi) # проверяем, достигнут ли конец строки
	jne printing_messages # если нет, то продолжаем

exit:
	call quit

usage:
	movl $4, %eax
	movl $1, %ebx
	movl $usage_str, %ecx
	movl $23, %edx
	int $0x80 # печатаем сообщение и выходим
	jmp exit
