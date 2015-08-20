.include "ii-functions.s"
.section .data
	template_simple:
		.ascii "\nAll\n...\n\n"
	template_repto:
		.ascii "\n@repto:"
	usage_str:
		.ascii "Usage: write <echoarea> [number]\n\0"
	editor:
		.ascii "/usr/bin/vim\0"
	editor_1: # программам нужно передавать в аргументах своё имя
		.ascii "vim\0"
	filename:
		.ascii "out/"
		.rept 40
		.byte 0
		.endr
	editor_args:
		.rept 3
		.long 0
		.endr
	echo_filedata: # эта память будет выделена динамически
		.long 0
	msg_filedata: # эта тоже
		.long 0
	msgnumber: # номер сообщения, на которое будем отвечать
		.long 0
	ncounter_1: # количество символов \n в сообщении; нужно для парсинга
		.long 0
	sender_charcount: # количество байтов в отправителе
		.long 0
	subj_charcount: # аналогично в сабже
		.long 0
	restring:
		.ascii "Re: "

.section .bss
	.lcomm currtime, 4 # текущий таймстамп
	.lcomm environment, 4 # указатель на переменные окружения
	.lcomm argc, 4
	.lcomm oldesp, 4
	.lcomm sender_pointer, 4 # указатель на отправителя
	.lcomm subj_pointer, 4
	.lcomm reptomsgid, 4 # сообщение, на которое отвечаем
	.lcomm file_descriptor, 4
	
.type gettime @function
.type gen_filename @function
.type asciidec_to_bin @function
.type openEditor @function
.globl main
.section .text

need_Re:
	movl $1, %eax
	movl 4(%esp), %ebx
	cmpl restring, %ebx

	je equal
	jne end
	
	equal:
		movl $0, %eax
	
	end:
	ret

openEditor:
	movl $editor_1, editor_args
	movl $filename, editor_args+4
	movl $11, %eax # нам нужно использовать execve
	movl $editor, %ebx
	movl $editor_args, %ecx
	movl environment, %edx # пишем указатель на переменные среды
	movl $2, %ebp # количество аргументов (без учёта нуля, конечно же)
	int $0x80
	ret

gettime:
	movl $13, %eax
	movl $0, %ebx
	int $0x80
	ret

gen_filename:
	# дружбо^Wмагическая функция, которая получает число, переводит его в 10-чный
	# вид и затем в ascii, попутно записывая результат в filename, чтобы
	# сгенерировать имя файла для нового сообщения

	movl 4(%esp), %eax
	movl $10, %ecx
	movl $10, %esi
	movl $0, %edx
	movl $filename+13, %ebx

	convert:
		divl %esi # делим eax на 10
		movb %dl, (%ebx)
		movl $0, %edx
		addb $0x30, (%ebx)
		decl %ebx
	loop convert
	ret

asciidec_to_bin:
	# тоже магия; по принципу действия
	# противоположна предыдущей функции.
	# вообще здесь много чего странно работает О_о

	movl 4(%esp), %eax
	movl $0, %ebx
	movl $0, %ecx
	
	convert_rev:
		cmpb $0, (%eax)
		je convert_rev_end

		subb $0x30, (%eax)
		imull $10, %ebx
		movb (%eax), %cl
		addl %ecx, %ebx
		incl %eax
		jmp convert_rev

	convert_rev_end:
	movl %ebx, msgnumber
	ret

main:
	movl %esp, oldesp
	
	movl 12(%esp), %eax # сохраняем указатель на
	movl %eax, environment # переменные среды

	movl 4(%esp), %eax
	movl %eax, argc # сохраняем argc
	cmpl $1, argc # и проверяем количество аргументов
	jle usage

	# аргументов 1 или более, вычисляем имя файла

	call gettime # получаем текущий таймстамп
	pushl %eax
	call gen_filename # переводим число в строку
	addl $4, %esp

	movl $5, %eax
	movl $filename, %ebx
	movl $1, %ecx # 1 - запись
	or $100, %ecx # добавляем флаг O_CREAT
	movl $0666, %edx
	int $0x80

	cmpl $0, %eax # если не получается открыть файл
	jl exit

	pushl %eax
	movl oldesp, %ebx # шаманство с аргументами
	movl 8(%ebx), %ecx

	pushl 4(%ecx) # название эхи

	call strlen

	movl %eax, %edx
	
	popl %ecx # название эхи
	popl %ebx # файловый дескриптор
	movl $4, %eax
	int $0x80 # пишем в файл название эхи
	movl %ebx, file_descriptor # сохраняем дескриптор, чтобы потом не мучаться

	cmpl $3, argc # если мы хотим ответить на сообщение,
	jge full_template # то идём вот сюда
	jne simple_template # иначе записываем упрощённый шаблон сообщения и выходим
	
	simple_template:
		movl $4, %eax
		movl $template_simple, %ecx
		movl $10, %edx
		int $0x80
		jmp endparse

	full_template:
		movl oldesp, %esi # опять танцы с бубном
		movl 8(%esi), %ecx

		pushl 8(%ecx) # пушим второй аргумент
		pushl 4(%ecx) # пушим первый аргумент

		call getLocalEcho
		movl %eax, echo_filedata
		addl $4, %esp

		call asciidec_to_bin # получаем номер сообщения
		addl $4, %esp

		cmpl $0, msgnumber
		jl endparse # проверка на отрицательность номера

		movl msgnumber, %eax
		imull $21, %eax
		cmpl last_size, %eax
		jge endparse # проверка на неправильный номер 2

		addl echo_filedata, %eax # получаем указатель на нужный msgid сообщения в эхе
		movl %eax, reptomsgid
		pushl %eax
		call getRawMsg

		# здесь опять магия
		jmp start_loop

		start_loop_inc:
		incl %eax

		start_loop:
		cmpb $'\n', (%eax) # проходимся по файлу и ищем \n
		jne start_loop_inc # не нашли, идём заново; неправильное сообщение породит
		# ... породит бесконечный цикл :D

		incl ncounter_1

		cmpl $3, ncounter_1 # проверяем, что находимся вблизи имени отправителя
		je start_sender
		jne end_sender
		
		start_sender:
			movl %eax, sender_pointer

		end_sender:
		cmpl $4, ncounter_1 # а теперь проверяем, что находимся в конце имени отправителя
		jne start_loop_inc

		incl %eax
		movl %eax, sender_charcount
		movl sender_pointer, %ecx
		subl %ecx, sender_charcount # вычисляем количество символов в отправителе

		pushl %eax
		movl $4, %eax # теперь записываем в файл, кому мы отвечаем
		movl file_descriptor, %ebx
		movl sender_pointer, %ecx
		movl sender_charcount, %edx
		int $0x80
	
		popl %eax # мы ещё не закончили извращаться с парсингом =)
		jmp start_loop_2 # дальше идут аналогичные процедуры, только для сабжа

		start_loop_inc_2:
		incl %eax

		start_loop_2:
		cmpb $'\n', (%eax)
		jne start_loop_inc_2

		incl ncounter_1

		cmpl $6, ncounter_1
		je start_subj
		jne end_subj
		
		start_subj:
			incl %eax
			movl %eax, subj_pointer

		end_subj:
		cmpl $7, ncounter_1
		jne start_loop_inc_2

		incl %eax
		movl %eax, subj_charcount
		movl subj_pointer, %ecx
		subl %ecx, subj_charcount
		
		pushl subj_pointer
		call need_Re
		cmpl $0, %eax
		je endwrite_Re

		write_Re:
			movl $4, %eax
			movl file_descriptor, %ebx
			movl $restring, %ecx
			movl $4, %edx
			int $0x80

		endwrite_Re:
		
		movl $4, %eax
		movl file_descriptor, %ebx
		movl subj_pointer, %ecx
		movl subj_charcount, %edx
		int $0x80
		
		# уфф, сабж написали
		# теперь на финишную прямую - пишем repto
		
		movl $4, %eax
		movl $template_repto, %ecx
		movl $8, %edx
		int $0x80

		movl $4, %eax
		movl reptomsgid, %ecx
		movl $20, %edx
		int $0x80
	
	endparse:

	movl $6, %eax # закрываем файл
	int $0x80

	call openEditor # открываем наш любимый вим с шаблоном сообщения
	call quit

exit:
	call quit

usage:
	movl $4, %eax
	movl $1, %ebx
	movl $usage_str, %ecx
	movl $33, %edx
	int $0x80 # печатаем сообщение и выходим
	jmp exit
