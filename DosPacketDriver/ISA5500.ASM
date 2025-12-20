version	equ	0
;History:562,1

;  Copyright, 1988-1992, Russell Nelson, Crynwr Software

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

	include	defs.asm

code	segment	word public
	assume	cs:code, ds:code

comment \

The following says how to transfer a sequence of bytes.  The bytes
are structured as [ count-low, count-high, bytes, bytes, bytes, checksum ].

Send		Recv
8->
[ repeat the following
		<-1
10h+low_nib->
		<-0
high_nib->
until all bytes have been transferred ]
		<-0
\

DATA		equ	0
REQUEST_IRQ	equ	08h
STATUS		equ	1
CONTROL		equ	2

PORTA8255	equ	0
PORTB8255	equ	1
PORTC8255	equ	2
CNTLP8255	equ	3

	public	int_no
int_no	db	3,0,0,0			;must be four bytes long for get_number.
io_addr	dw	0330h,0			; I/O address for card (jumpers)

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	1,0		;null terminated list of classes.
driver_type	db	90		;from the packet spec
driver_name	db	'isa5500',0	;name of the driver.
driver_function	db	2
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	0	;(# of back-to-back MTU rcvs) - 1
	dw	0	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

recv_buffer	dw	?		;-> buffer.
recv_count	dw	?

send_nib_count	db	?
recv_byte_count	db	?

	public	rcv_modes
rcv_modes	dw	7		;number of receive modes in our table.
		dw	0,0,0,rcv_mode_3
		dw	0,0,rcv_mode_6

	include	timeout.asm

hexout_ptr	dw	0
hexout_color	db	70h

hexout_more:
;	ret
	push	di
	mov	di,cs:hexout_ptr
	call	hexout
	add	di,4
	cmp	di,25*80*2
	jb	hexout_more_1
	xor	di,di
hexout_more_1:
	mov	cs:hexout_ptr,di
	pop	di
	ret

hexout:
;enter with al = number, di->place on screen to store chars.
	push	ax
	push	es

	push	di
	mov	di,0b800h
	mov	es,di
	pop	di

	push	ax
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1
	call	nibble2hex
	mov	byte ptr es:[di+0],al
	mov	al,cs:hexout_color
	mov	byte ptr es:[di+1],al
	pop	ax
	call	nibble2hex
	mov	byte ptr es:[di+2],al
	mov	al,cs:hexout_color
	mov	byte ptr es:[di+3],al

	pop	es
	pop	ax
	ret


nibble2hex:
	and	al,0fh
	add	al,90h			;binary digit to ascii hex digit.
	daa
	adc	al,40h
	daa
	ret


	public bad_command_intercept
bad_command_intercept:
;called with ah=command, unknown to the skeleton.
;exit with nc if okay, cy, dh=error if not.
	mov	dh,BAD_COMMAND
	stc
	ret

	public	as_send_pkt
; The Asynchronous Transmit Packet routine.
; Enter with es:di -> i/o control block, ds:si -> packet, cx = packet length,
;   interrupts possibly enabled.
; Exit with nc if ok, or else cy if error, dh set to error number.
;   es:di and interrupt enable flag preserved on exit.
as_send_pkt:
	ret

	public	drop_pkt
; Drop a packet from the queue.
; Enter with es:di -> iocb.
drop_pkt:
	assume	ds:nothing
	ret

	public	xmit
; Process a transmit interrupt with the least possible latency to achieve
;   back-to-back packet transmissions.
; May only use ax and dx.
xmit:
	assume	ds:nothing
	ret

send_8255:
	mov dx,io_addr
;	add	dl,PORTA8255
	out	dx,al
	add	dl,PORTC8255-PORTA8255
wait_send_8255:
	in	al,dx
	test	al,080h
	jz	wait_send_8255
	ret

recv_8255:
	mov dx,io_addr
	add	dl,PORTC8255
wait_recv_8255:
	in	al,dx
	test	al,020h
	jz	wait_recv_8255
	sub	dl,PORTC8255-PORTA8255
	in	al,dx
	ret

send_8255_timeout:
	push	dx
	push	cx
	xor		cx,cx
	mov	dx,io_addr
;	add	dl,PORTA8255
	out		dx,al
	add	dl,PORTC8255-PORTA8255
send_8255_timeout_1:
	in		al,dx
	test	al,080h
	jnz	send_8255_timeout_recv
	loop	send_8255_timeout_1
	stc
send_8255_timeout_2:
	pop		cx
	pop		dx
	ret
send_8255_timeout_recv:
	clc
	jmp		send_8255_timeout_2

recv_8255_timeout:
	push	dx
	push	cx
	xor		cx,cx
	mov	dx,io_addr
	add		dl,PORTC8255-PORTA8255
recv_8255_timeout_1:
	in		al,dx
	test	al,020h
	jnz		recv_8255_timeout_recv
	loop	recv_8255_timeout_1
	stc
	jmp		send_8255_timeout_2
recv_8255_timeout_recv:
	sub		dl,PORTC8255-PORTA8255
	in		al,dx
	clc
	jmp		send_8255_timeout_2


	public	send_pkt
send_pkt:
;enter with es:di->upcall routine, (0:0) if no upcall is desired.
;  (only if the high-performance bit is set in driver_function)
;enter with ds:si -> packet, cx = packet length.
;if we're a high-performance driver, es:di -> upcall.
;exit with nc if ok, or else cy if error, dh set to error number.
	assume	ds:nothing

	cmp	cx,GIANT		; Is this packet too large?
	ja	send_pkt_toobig

;set up 8255 just in case
	mov	dx,io_addr
	add	dl,CNTLP8255
	mov	al,0FAh		; set up mode
	out	dx,al
	mov	al,01h		; set bit C0 to 1 to denote we're busy
	out	dx,al

	mov	al,083h
	call	send_8255
	;call	hexout_more
	mov	al,cl
	call	send_8255
	;call	hexout_more
	mov	al,ch
	call	send_8255
	;call	hexout_more

;send packet
send_packet:
	lodsb
	call	send_8255
	loop	send_packet

; get status byte
	call	recv_8255
	
	mov	cl,al
	;call	hexout_more
	mov	dx,io_addr
	add	dl,CNTLP8255
	xor	al,al
	out	dx,al
	rcr	cl,1
	ret

send_pkt_toobig:
	mov	dh,NO_SPACE
	stc
	ret

isa5500_initialize:
	public	set_address
set_address:
;enter with ds:si -> Ethernet address, CX = length of address.
;exit with nc if okay, or cy, dh=error if any errors.
	assume	ds:nothing
	mov	dx,io_addr
	add	dl,CNTLP8255
	mov	al,0FAh		; set up mode
	out	dx,al
	mov	al,01h		; set bit C0 to 1 to denote we're busy
	out	dx,al

	mov	al,085h
	call	send_8255_timeout
	jc	set_address_error
	;call	send_8255
	;call	hexout_more

set_address_send:
	lodsb
	;call	send_8255
	call	send_8255_timeout
	jc	set_address_error
	;call	hexout_more
	loop	set_address_send

	;call	recv_8255
	call	recv_8255_timeout	; get status code
	jc	set_address_error
	;call	hexout_more
	mov	cl,al
	mov	dx,io_addr
	add	dl,CNTLP8255
	xor	ax,ax
	out	dx,al

	;mov		al,cl
	;call	hexout_more
	test	cl,cl
	jnz		set_address_error

	clc
	ret

set_address_error:
	mov	dh,CANT_RESET
	stc
	ret


rcv_mode_3:
rcv_mode_6:
;receive mode 3 is the only one we support, so we don't have to do anything.
	ret


	public	set_multicast_list
set_multicast_list:
;enter with ds:si ->list of multicast addresses, ax = number of addresses,
;  cx = number of bytes.
;return nc if we set all of them, or cy,dh=error if we didn't.
	mov	dh,NO_MULTICAST
	stc
	ret


	public	terminate
terminate:
	ret


	public	reset_interface
reset_interface:
;reset the interface.
	assume	ds:code
	ret


;called when we want to determine what to do with a received packet.
;enter with cx = packet length, es:di -> packet type, dl = packet class.
	extrn	recv_find: near

;called after we have copied the packet into the buffer.
;enter with ds:si ->the packet, cx = length of the packet.
	extrn	recv_copy: near

;call this routine to schedule a subroutine that gets run after the
;recv_isr.  This is done by stuffing routine's address in place
;of the recv_isr iret's address.  This routine should push the flags when it
;is entered, and should jump to recv_exiting_exit to leave.
;enter with ax = address of routine to run.
	extrn	schedule_exiting: near

;recv_exiting jumps here to exit, after pushing the flags.
	extrn	recv_exiting_exit: near

;enter with dx = amount of memory desired.
;exit with nc, dx -> that memory, or cy if there isn't enough memory.
	extrn	malloc: near

	extrn	count_in_err: near
	extrn	count_out_err: near

recv_char	db	'0'

recv_abort_int:
	call	count_in_err
	ret

	public	recv
recv:
;called from the recv isr.  All registers have been saved, and ds=cs.
;Upon exit, the interrupt will be acknowledged.
	assume	ds:code

	mov	dx,io_addr
	;add	dl,PORTB8255
	inc	dl				; set up PORT B
	in	al,dx
	test	al,80h		; see if hi bit is one
	jz	recv_abort_int	; abort the interrupt if it is not asserted
	;add	dl,PORTC8255-PORTB8255
	inc	dl
	in	al,dx
	test	al,01h		; see if lowest bit is one
	jnz	recv_abort_int	; something else is happening, can't get this

	;mov	byte ptr hexout_color,020h

	;mov	al,0AAh
	;call	hexout_more

recv_begin:

	mov	al,084h		; read packet command
	call	send_8255
	mov	al,GIANT mod 256
	call	send_8255
	mov	al,GIANT/256
	call	send_8255

	call	recv_8255
	mov	cl,al
	;call	hexout_more
	call	recv_8255
	mov	ch,al
	;call	hexout_more
	mov	recv_count,cx
	test	cx,cx
	jz	recv_abort_int

	movseg	es,ds
	mov	di,recv_buffer

recv_pkt_loop:
	call	recv_8255
	stosb
	loop	recv_pkt_loop

	;mov	al,0BBh
	;call	hexout_more

recv_pkt_process:
	movseg	es,cs
	mov	di,recv_buffer
	push	es
	push	di

	mov	cx,recv_count
	add	di,EADDR_LEN+EADDR_LEN	;skip the ethernet addreses and
					;  point to the packet type.
	mov	dl, BLUEBOOK		;assume bluebook Ethernet.
	mov	ax, es:[di]
	xchg	ah, al
	cmp 	ax, 1500
	ja	BlueBookPacket
	inc	di			;set di to 802.2 header
	inc	di
	mov	dl, IEEE8023
BlueBookPacket:
	;mov	al,dl
	;call	hexout_more

	push	cx
	call	recv_find

	pop	cx
	pop	si
	pop	ds
	assume	ds:nothing

	;mov	al,0CCh
	;call	hexout_more

	mov	ax,es			;is this pointer null?
	or	ax,di
	je	recv_free		;yes - just free the frame.

	push	es
	push	di
	push	cx
	rep	movsb
	pop	cx
	pop	si
	pop	ds

	;mov	al,0DDh
	;call	hexout_more

	assume	ds:nothing

	call	recv_copy

	;mov	al,0EEh
	;call	hexout_more

;	jmp	short recv_free

recv_free:

	;mov	byte ptr hexout_color,070h
	movseg	ds,cs
	ret


	public	timer_isr
timer_isr:
;if the first instruction is an iret, then the timer is not hooked
	iret

;any code after this will not be kept after initialization. Buffers
;used by the program, if any, are allocated from the memory between
;end_resident and end_free_mem.
	public end_resident,end_free_mem
end_resident	label	byte
	db	GIANT dup(?)
end_free_mem	label	byte


	public	usage_msg
usage_msg	db	"usage: isa5500 [options] <packet_int_no> [-t] <hardware_irq> <io_addr> [<Ethernet_address>]",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for ISA SD/ethernet interface, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,CR,LF
		db	"Portions Copyright 1992, Russell Nelson, 2025 Daniel Marks",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in ISA5500.ASM",CR,LF,'$'
init_failed_msg	db	"Initialization failed",CR,LF,'$'

int_no_name	db	"Interrupt number ",'$'
io_addr_name	db	"I/O port ",'$'

test_switch	db	0
test_bit	db	1

	extrn	set_recv_isr: near

	extrn	chrout: near
	extrn	skip_blanks: near

	extrn	incval: near

;enter with si -> argument string, di -> dword to store.
;if there is no number, don't change the number.
	extrn	get_number: near

;enter with dx -> argument string, di -> dword to print.
	extrn	print_number: near

;-> the assigned Ethernet address of the card.
	extrn	rom_address: byte

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	call	skip_blanks
	cmp	al,'-'			;did they specify a switch?
	jne	not_switch
	cmp	byte ptr [si+1],'t'	;did they specify '-t'?
	je	got_test_switch
	stc				;no, must be an error.
	ret
got_test_switch:
	mov	test_switch,1
	add	si,2			;skip past the switch's characters.
	jmp	parse_args		;go parse more arguments.
not_switch:

	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number

	mov	rom_address[0],2	;locally administered.

	mov	ax,40h
	mov	es,ax
	mov	ax,es:[6ch]
	mov	word ptr rom_address[2],ax
	mov	ax,es:[6eh]
	mov	word ptr rom_address[4],ax

	movseg	es,ds
	mov	di,offset rom_address
	call	get_eaddr
	clc
	ret


	public	etopen
etopen:
	mov	si,offset rom_address
	mov	cx,6
	call	isa5500_initialize
	jnc		etopen_1
	stc
	mov	dx,offset init_failed_msg
	ret

etopen_1:

	mov	dx,GIANT		;allocate memory for the receive buffer.
	call	malloc
	jc	no_memory
	mov	recv_buffer,dx

	call	set_recv_isr

	mov	al, int_no		; Get board's interrupt vector
	add	al, 8
	cmp	al, 8+8			; Is it a slave 8259 interrupt?
	jb	set_int_num		; No.
	add	al, 70h - 8 - 8		; Map it to the real interrupt.
set_int_num:
	xor	ah, ah			; Clear high byte
	mov	int_num, ax		; Set parameter_list int num.

	clc
	ret
no_memory:
	mov	dx,offset no_memory_msg
	stc
	ret

	public	print_parameters
print_parameters:
;echo our command-line parameters
	mov	di,offset int_no
	mov	dx,offset int_no_name
	call	print_number
	mov	di,offset io_addr
	mov	dx,offset io_addr_name
	call	print_number
	ret

	extrn	get_hex: near
	include	getea.asm

code	ends

	end
