.include "ii-functions.s"
# .include "b64.s"
.include "network-functions.s"
.section .data
	tossesdir:
		.ascii "out/\0"
	sentdir:
		.ascii "sent/\0"
	station:
		.ascii "http://alicorn.tk/ii/ii-point.php?q=/u/point\0"
	request_1:
		.ascii "pauth=your_authstr&tmsg=\0"

.section .bss
	.lcomm dirent, 266 # struct old_linux_dirent
	.lcomm request_size, 4
	.lcomm b64_size, 4
	.lcomm b64_pointer, 4
	.lcomm first_break, 4
	.lcomm second_break, 4
	.lcomm tossesdir_descriptor, 4
	.lcomm sentdir_descriptor, 4
	
# .type  @function
.globl main
.section .text

main:
	call get_break # получаем границу невыделенной памяти
	movl %eax, first_break

	# открываем директорию
	movl $5, %eax
	movl $tossesdir, %ebx
	movl $00200000, %ecx # флаг O_DIRECTORY
	movl $0666, %edx
	int $0x80

	movl %eax, tossesdir_descriptor # дескриптор директории out/

	movl $5, %eax # открываем директорию отправленных
	movl $sentdir, %ebx
	int $0x80

	movl %eax, sentdir_descriptor # sent/

	reading_filenames:

	movl tossesdir_descriptor, %ebx
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
	movl tossesdir_descriptor, %ebx
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
	
	movl %eax, %ebx # читаем информацию из файла
	movl $3, %eax
	movl first_break, %ecx
	movl last_size, %edx
	int $0x80

	movl $6, %eax
	int $0x80 # закрываем файл
	
	# теперь по адресу first_break находится нужный тосс, который нам отправлять
	pushl first_break
	call b64c
	addl $4, %esp
	
	pushl $0
	pushl %eax
	pushl curl
	call curl_easy_escape
	addl $12, %esp
	movl %eax, b64_pointer

	pushl %eax
	call strlen
	addl $4, %esp
	movl %eax, b64_size

	pushl $request_1
	call strlen
	movl %eax, request_size
	addl $4, %esp

	movl b64_size, %ebx
	addl request_size, %ebx

	pushl %ebx
	call get_memory # выделяем память для post-запроса
	addl $4, %esp
	
	movl %eax, second_break
	
	# делаем подобное strcat
	# 1 - для запроса
	movl $request_1, %esi
	movl second_break, %edi
	movl request_size, %ecx
	rep movsb
	
	# 2 - для base64-сообщения
	movl b64_pointer, %esi
	movl second_break, %edi
	addl request_size, %edi
	movl b64_size, %ecx
	rep movsb

	# отправляем post-запрос
	pushl second_break
	pushl $station
	call send_post
	addl $8, %esp

	# будем считать, что post сработал нормально
	# теперь перемещаем сообщение из out/ в sent/
	# используем сисколл renameat
	movl $302, %eax
	movl tossesdir_descriptor, %ebx
	movl $dirent+10, %ecx
	movl sentdir_descriptor, %edx
	movl %ecx, %esi
	int $0x80

	jmp reading_filenames # читаем дальше

exit:
	# закрываем наши директории
	movl $6, %eax
	movl tossesdir_descriptor, %ebx
	int $0x80

	movl $6, %eax
	movl sentdir_descriptor, %ebx
	int $0x80

	call quit
