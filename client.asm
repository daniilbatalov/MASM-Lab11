			title		client
			assume		cs:c, ss:s, ds:d

s			segment		stack

			dw			128 dup(?)

s			ends

d			segment

cr = 0dh
lf = 0ah

sizeMatrix	dw			0
i			dw			0
j			dw			0
welcome		db			"Client$"
GetSuccess	db			"The data fetch was ok!$", 0DH, 0AH, '$'
SendSuccess	db			"The data send was ok!$", 0DH, 0AH, '$'
Waiting		db			"Waiting...$"
size?		db			"Enter the matrix order (<= 10): $"
space		db			" $"
timeout		db			"Timeout!$"
tab			db			09h, "$"
negflag		dw			?
string		db			255, 0, 255 dup (?)
errmsg		db			'Error! Invalid character!', 0DH, 0AH, '$'
err_size	db			'Error! Wrong matrix order!', 0DH, 0AH, '$'
a			dw			10 dup (10 dup (?))
ma 			dw			?
msgx		db 			0DH, 0AH, 'Enter the next element of matrix: $'
msgo 		db			'Original matrix:', 0DH, 0AH, '$'
msgr		db			'Result matrix:', 0DH, 0AH, '$'
msgm		db 			0DH, 0AH, 'Enter m: $'
d			ends

c			segment

write 		macro		STR
			push		ax
			push		dx
			mov			ah, 9
			lea			dx, STR
			int			21h
			pop			dx
			pop			ax
			endm


writeln		macro		STR
			push		ax
			push		dx
			mov			ah, 9
			lea			dx, STR
			int			21h
			call		NewLine
			pop			dx
			pop			ax
			endm

NewLine		proc
			push		ax
			push		dx

			mov			ah, 02H
			mov			dl, 0AH
			int			21H

			mov			ah, 02H
			mov			dl, 0DH
			int			21H

			pop			dx
			pop			ax
			ret
NewLine		endp			

SendByte	macro		SB_VALUE
			local		SB_wait1, SB_wait2
			mov			ax, 18*18
			mov			cs:[delay], ax

SB_wait1:	cmp			cs:[delay], 0
			jg			SB_wait2
			writeln		timeout
			jmp			exit

SB_wait2:	mov			dx, 3fdh
			in			al, dx
			rcl			al, 1
			rcl			al, 1
			jnc			SB_wait1
								;load a byte, then send
			mov			dx, 3f8h
			mov			al, SB_VALUE
			out			dx, al
			endm

GetByte		macro		Gb_DELAY
			local		Gb_wait1, Gb_wait2
			mov			ax, Gb_DELAY
			mov			cs:[delay], ax

Gb_wait1:	cmp			cs:[delay], 0
			jg			Gb_wait2
			writeln		timeout
			jmp			exit

Gb_wait2:	mov	    	dx, 3fdh		;if the 0th bit zero, the data is ready for read
			in			al, dx
			rcr			al, 1
			jnc			Gb_wait1		;load a byte, then send
			mov			dx, 3f8h
			in			al, dx

			endm
		
InitCom		proc
			push		dx
			push		ax

		;1 - порты 3F8h и 3F9h
		;используется для загрузки делителя частоты тактового генератора
			mov			dx, 3fbh
			in			al, dx
			or			al, 10000000b
			out			dx, al

		;Скорость передачи (младший бит)
			mov			dx, 3f8h
			mov			al, 12
			out			dx, al

		;старший бит тактовой частоты
			mov			al, 0
			mov			dx, 3f9h
			out			dx, al

		;Длина слова в байтах (11 - 8 бит)
			mov		dx, 3fbh
			mov		al, 00000011b
			out		dx, al

		;Запуск диагностики при входе асинхронного 
		;адаптера, замкнутом на его выход. (4 бит)
			mov		dx, 3fch
			in		al, dx
			and		al, 11101111b
			out		dx, al

		;сброс
			mov		dx, 3f8h
			in		al, dx
			in		al, dx
		
			pop		ax
			pop		dx
			ret
InitCom		endp

PrintSpace	proc
			push		ax
			push		dx

			mov			ah, 02H
			mov			dl, 20H
			int			21H

			pop			dx
			pop			ax
			ret
PrintSpace	endp

PrintMatrix proc
			xor			si, si
			mov			cx, sizeMatrix

outer_pnt:	push		cx
			mov			cx, sizeMatrix
			xor			bx, bx

inner_pnt:	mov			ax, a[si+bx]
			Call		IntegerOut
			Call		PrintSpace

			add			bx, 2
			loop		inner_pnt
			Call		NewLine
			add			si, 20
			pop			cx
			loop		outer_pnt

			ret			
PrintMatrix endp

IntegerIn	proc
			push		dx
			push		si
			push		bx

startp:		mov			ah, 0AH
			lea			dx, string
			int 		21H

			xor			ax, ax
			lea			si, string+2
			mov			negflag, ax
			cmp			byte ptr [si], '-'
			jne			m2

			not			negflag
			inc			si
			jmp			m
m2:			cmp			byte ptr [si], '+'
			jne			m
			inc			si
m:			cmp			byte ptr [si], cr
			je			exl
			cmp			byte ptr [si], '0'
			jb			err
			cmp			byte ptr [si], '9'
			ja			err

			mov			bx, 10
			mul			bx

			sub			byte ptr [si], '0'
			add			al, [si]
			adc			ah, 0

			inc			si
			jmp			m

err:		lea 		dx, errmsg
			mov			ah, 9
			int			21H
			jmp			startp

exl:		cmp			negflag, 0
			je 			ex
			neg			ax

ex: 		pop			bx
			pop			si
			pop			dx


			ret
IntegerIn	endp

IntegerOut	proc
			push		cx
			push		bx

			xor			cx, cx
			mov			bx,	10
			cmp			ax, 0
			jge			m0
			neg			ax
			push		ax
			mov			ah,	2
			mov			dl,	'-'
			int			21H
			pop			ax

m0:			inc			cx
			xor			dx, dx
			div			bx
			push		dx
			or			ax, ax
			jnz			m0

m11:		pop 		dx
			add			dx, '0'
			mov			ah,	2
			int			21H
			loop		m11

			pop			bx
			pop			cx
			ret
IntegerOut	endp

SendWord	proc
			push		ax
			push		bx
			mov			bx, ax
			SendByte	bl
			SendByte	bh
			pop			bx
			pop			ax
			ret
SendWord	endp

GetWord		proc
			push		bx
			GetByte		30000
			mov			bl, al
			GetByte		1000
			mov			bh, al
			mov			ax, bx
			pop			bx
			ret
GetWord		endp

old1c		dd			?
delay		dw			?

begin:		mov			ax, d
			mov			ds, ax
			call		InitCom
			push		es
			mov			ax, 351ch
			int			21h
			mov			word ptr cs:[old1c], bx
			mov			word ptr cs:[old1c + 2], es
			pop			es

			mov			ax, 251ch
			lea			dx, handler
			push		ds
			push		cs
			pop			ds
			int			21h
			pop			ds

			writeln		welcome

m1:			write		size?
			call		IntegerIn
			cmp			ax, 0
			jg			m22
			writeln		err_size
			jmp			m1

m22:		cmp			ax, 10
			jl			m3
			writeln		err_size
			jmp			m1

m3:			mov			sizeMatrix, ax
			call		SendWord
			writeln		SendSuccess
			call		NewLine

			mov			cx, sizeMatrix
			xor			si, si

enter_i:	push		cx
			mov			cx, sizeMatrix

enter_j:	write		msgx
			call		IntegerIn
			call		SendWord
			loop		enter_j
			pop			cx
			loop		enter_i
     
			write		msgm
			call		IntegerIn
			call		SendWord

			mov			cx, sizeMatrix
			xor			si, si
get_i:		push		cx
			mov			cx, sizeMatrix
			xor			bx, bx
get_j:		call		GetWord
			mov			a[si+bx], ax
			add			bx, 2
			loop		get_j
			add			si, 20
			pop			cx
			loop		get_i


			writeln		msgr
			call		PrintMatrix

exit:		mov			ax, word ptr cs:[old1c + 2]
			mov			ds, ax
			mov			dx, word ptr cs:[old1c]
			mov			ax, 251ch
			int			21h
			mov			ah, 4ch
			int			21h

handler:	sti
			dec			cs:[delay]
			pushf
			call		dword ptr cs:[old1c]
			cli
			iret

c			ends
			end			begin

