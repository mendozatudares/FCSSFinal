; #########################################################################
;
;   lines.asm - Assembly file for CompEng205 Assignment 2
;   Kevin Mendoza Tudares
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include stars.inc
include lines.inc

.DATA

	;; If you need to, you can place global variables here

.CODE


;; Don't forget to add the USES the directive here
;;   Place any registers that you modify (either explicitly or implicitly)
;;   into the USES list so that caller's values can be preserved

;;   For example, if your procedure uses only the eax and ebx registers
;;      DrawLine PROC USES eax ebx x0:DWORD, y0:DWORD, x1:DWORD, y1:DWORD, color:DWORD
DrawLine PROC USES ebx ecx edx x0:DWORD, y0:DWORD, x1:DWORD, y1:DWORD, color:DWORD
	;; Feel free to use local variables...declare them here
	;; For example:
	;; 	LOCAL foo:DWORD, bar:DWORD
	LOCAL delta_x:DWORD, delta_y:DWORD, inc_x:DWORD, inc_y:DWORD

	;; Place your code here
	;; Initialize variables
	mov inc_x, 1
	mov inc_y, 1

	;; Calculate delta_x, store in eax
def_delta_x:
	mov eax, x1
	sub eax, x0		;; eax = x1 - x0
	test eax, eax
	jns def_delta_y	;; jump if x0 < x1
	neg eax			;; delta_x = - delta_x
	mov inc_x, -1	;; if x0 >= x1, inc_x = -1

	;; Calculate delta_y, store in ebx
def_delta_y:
	mov ebx, y1
	sub ebx, y0		;; ebx = y0 - y1
	test ebx, ebx
	jns def_error	;; jump if y0 < y1
	neg ebx			;; delta_y = - delta_y
	mov inc_y, -1	;; if y0 >= y1, inc_y = -1

	;; Calculate error, store in ecx
def_error:
	cmp eax, ebx
	jbe error_y		;; jump if delta_x <= delta_y
	mov ecx, eax	;; error = delta_x
	jmp error_shift
error_y:
	mov ecx, ebx	;; error = - delta_y
	neg ecx
error_shift:
	sar ecx, 1		;; error /= 2

	invoke DrawPixel, x0, y0, color
	mov delta_x, eax ;; store delta_x
	mov delta_y, ebx ;; store delta_y
	mov eax, x0		 ;; curr_x = x0
	mov ebx, y0		 ;; curr_y = y0

compare:
	cmp eax, x1
	jne draw_loop	 ;; if curr_x != x1 ...
	cmp ebx, y1
	je done			 ;; or if curr_y != y1, done

draw_loop:
	invoke DrawPixel, eax, ebx, color
	mov edx, ecx	 ;; prev_error = error

compare_x:
	neg delta_x
	cmp edx, delta_x
	jle compare_y	 ;; jump if prev_error <= - delta_x
	sub ecx, delta_y ;; error -= delta_y
	add eax, inc_x	 ;; curr_x += inc_x

compare_y:
	neg delta_x
	cmp edx, delta_y
	jge compare		 ;; jump if prev_error >= delta_y
	add ecx, delta_x ;; error += delta_x
	add ebx, inc_y	 ;; curr_y += inc_y
	jmp compare

done:
	ret        	;;  Don't delete this line...you need it
DrawLine ENDP

END
