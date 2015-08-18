.include "ii-functions.s"
.section .data
	filename:
		.ascii "out/"
		.rept 40
		.byte 0
		.endr
	station:
		.ascii "http://ii-net.tk/ii/ii-point.php?q=/u/point\0"
	authstr:
		.ascii "your_authstr\0"

.section .bss
	.lcomm file_descriptor, 4
	.lcomm dirent, 266 # struct old_linux_dirent
	.lcomm first_break, 4
	
# .type  @function
.globl main
.section .text

main:
	call get_break # получаем границу невыделенной памяти
	movl %eax, first_break

	# открываем директорию
	movl $5, %eax
	movl $filename, %ebx
	movl $00200000, %ecx # флаг O_DIRECTORY
	movl $0666, %edx
	int $0x80

	pushl %eax # дескриптор директории out/

	reading_filenames:

	movl (%esp), %ebx
	movl $89, %eax # readdir
	movl $dirent, %ecx
	movl $0, %edx
	int $0x80

	cmpl $0, %eax # если нет файлов или ошибка, завершаем работу
	jle exit

	# dirent+10 - это смещение до первого символа имени файла
	cmpb $'.', dirent+10 # если файл начинается с точки, то 
	je reading_filenames # то он нам не нужен, читаем следующий файл

	# здесь начинаем основной код
	movl $300, %eax # fstatat;
	movl (%esp), %ebx
	movl $dirent+10, %ecx
	movl $stt, %edx
	movl $0, %esi
	int $0x80

	pushl %ebx

	movl 44(%edx), %eax # сохраняем размер файла в out/
	movl %eax, last_size
	
	addl first_break, %eax # выделяем память с самого начала, ненужное отсекаем
	pushl %eax
	call set_break
	addl $4, %esp

	movl $295, %eax # открываем файл в out/, сисколл openat
	popl %ebx # дескриптор директории
	movl $dirent+10, %ecx
	movl $0, %edx
	int $0x80
	
	movl %eax, %ebx
	movl $3, %eax
	movl first_break, %ecx
	movl last_size, %edx
	int $0x80
	
	# теперь по адресу first_break находится нужный тосс, который нам отправлять
	# продолжение следует

	jmp reading_filenames # читаем дальше

exit:
	call quit
