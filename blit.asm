; #########################################################################
;
;   blit.asm - Assembly file for CompEng205 Assignment 3
;
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include stars.inc
include lines.inc
include trig.inc
include blit.inc


.DATA

	;; If you need to, you can place global variables here
	ScreenWidth DWORD 640
	ScreenMax DWORD 307200

.CODE

DrawPixel PROC USES ecx edx x:DWORD, y:DWORD, color:DWORD
	
	mov eax, y					;; eax <- y
	mul ScreenWidth				;; multiply y by width of screen
	add eax, x					;; eax <- y*640 + x, used to index bytes in backbuffer
	
	cmp eax, 0					;; check if calculated index is less than 0
	jl done						;; if so, index is out of bounds
	cmp eax, ScreenMax			;; check if calculated index is greater than max
	jg done						;; if so, index is out of bounds

	add eax, ScreenBitsPtr		;; eax <- ScreenBitsPtr + (y*640 + x), final address of byte
	mov edx, color				;; edx <- color value
	mov [eax], dl				;; set backbuffer byte to color value

done:
	ret 			; Don't delete this line!!!
DrawPixel ENDP

BasicBlit PROC ptrBitmap:PTR EECS205BITMAP , xcenter:DWORD, ycenter:DWORD

	INVOKE RotateBlit, ptrBitmap, xcenter, ycenter, 0

	ret 			; Don't delete this line!!!	
BasicBlit ENDP


RotateBlit PROC USES ebx ecx edx esi edi lpBmp:PTR EECS205BITMAP, xcenter:DWORD, ycenter:DWORD, angle:FXPT
	LOCAL cosa:FXPT, sina:FXPT, shiftX:SDWORD, shiftY:SDWORD, dst:DWORD, srcX:SDWORD, srcY:SDWORD, trans: BYTE
	
	INVOKE FixedCos, angle
	mov cosa, eax				;; cosa = FixedCos(angle)
	INVOKE FixedSin, angle
	mov sina, eax				;; sina = FixedSin(angle)
	
	mov esi, lpBmp				;; esi = lpBitmap
	mov al, (EECS205BITMAP PTR [esi]).bTransparent
	mov trans, al				;; trans <- (EECE205BITMAP PTR [esi]).bTransparent

	mov eax, (EECS205BITMAP PTR [esi]).dwWidth	;; eax <- dwWidth
	shl eax, 16					;; represent as FXPT
	imul cosa					;; dwWight * cosa
	shl edx, 16
	shr eax, 16
	or edx, eax					;; edx <- dwWidth * cosa
	mov shiftX, edx
	mov eax, (EECS205BITMAP PTR [esi]).dwHeight	;; eax <- dwHeight
	shl eax, 16					;; represent as FXPT
	imul sina					;; dwHeight * sina
	shl edx, 16
	shr eax, 16
	or edx, eax					;; edx <- dwHeight * sina
	sub shiftX, edx				;; shiftX <- dwWidth * cosa - dwHeight * sina
	adc shiftX, 0ffffh			;; rounding
	sar shiftX, 17				;; convert shiftX to integer, divide by 2

	mov eax, (EECS205BITMAP PTR [esi]).dwHeight	;; eax <- dwHeight
	shl eax, 16					;; represent as FXPT
	mul	cosa					;; dwHeight * cosa
	shl edx, 16
	shr eax, 16
	or edx, eax					;; edx <- dwHeight * cosa
	mov shiftY, edx
	mov eax, (EECS205BITMAP PTR [esi]).dwWidth	;; eax <- dwWidth
	shl eax, 16					;; represent as FXPT
	imul sina					;; dwHeight * sina
	shl edx, 16
	shr eax, 16
	or edx, eax					;; edx <- dwWidth * sina
	add shiftY, edx				;; shiftY <- dwHeight * cosa + dwWidth * sina
	adc shiftY, 0ffffh			;; rounding
	sar shiftY, 17				;; convert shiftY to integer, divide by 2

	mov eax, (EECS205BITMAP PTR [esi]).dwWidth	;; eax <- dwWidth
	add eax, (EECS205BITMAP PTR [esi]).dwHeight	;; eax <- dwHeight
	mov dst, eax				;; dst = dstHeight = dstWidth = dwWidth + dwHeight

	mov ebx, dst
	neg ebx						;; ebx <- dstX = -dstWidth = -dst
	jmp evalX
doX:
	mov ecx, dst
	neg ecx						;; ecx <- dstY = -dstHeight = -dst
	jmp evalY
doY:
	mov eax, ebx				;; eax <- dstX
	shl eax, 16					;; represent as FXPT
	imul cosa					;; dstX * cosa
	shl edx, 16
	shr eax, 16
	or edx, eax					;; edx <- dstX * cosa
	mov srcX, edx
	mov eax, ecx				;; eax <- dstY
	shl eax, 16					;; represent as FXPT
	imul sina					;; dstY * sina
	shl edx, 16
	shr eax, 16
	or edx, eax
	add srcX, edx				;; srcX = dstX * cosa + dstY * sina
	adc srcX, 7fffh				;; rounding
	sar srcX, 16				;; convert to integer
	
	mov eax, ecx				;; eax <- dstY
	shl eax, 16					;; represent as FXPT
	imul cosa					;; dstY * cosa
	shl edx, 16
	shr eax, 16
	or edx, eax
	mov srcY, edx
	mov eax, ebx				;; eax <- dstX
	shl eax, 16					;; represent as FXPT
	imul sina					;; dstX * sina
	shl edx, 16
	shr eax, 16
	or edx, eax
	sub srcY, edx				;; srcY = dstY * cosa - dstX * sina
	adc srcY, 7fffh				;; rounding
	sar srcY, 16				;; convert to integer

	cmp srcX, 0					;; draw only if ...
	jl incY
	mov eax, (EECS205BITMAP PTR [esi]).dwWidth	;; eax <- dwWidth
	cmp srcX, eax				;; x is within bitmap bounds ...
	jge incY					;; 0 <= srcX < dwWidth && ...

	cmp srcY, 0
	jl incY
	mov eax, (EECS205BITMAP PTR [esi]).dwHeight	;; eax <- dwHeight
	cmp srcY, eax				;; y is within bitmap bounds ...
	jge incY					;; 0 <= srcY < dwHeight && ...

	mov eax, xcenter
	add eax, ebx
	sub eax, shiftX
	cmp eax, 0
	jl incY
	cmp eax, 639				;; x coordinate is within screen bounds ...
	jge incY					;; 0 <= (xcenter + dstX - shiftX) < 639 && ...

	mov edi, ycenter
	add edi, ecx
	sub edi, shiftY
	cmp edi, 0
	jl incY
	cmp edi, 479				;; y coordinate is within screen bounds ...
	jge incY					;; 0 <= (ycenter + dstY - shiftY) < 479 && ...

	mov edx, srcY
	imul edx, (EECS205BITMAP PTR [esi]).dwWidth
	add edx, srcX
	mov dl, BYTE PTR [(EECS205BITMAP PTR [esi]).lpBytes + edx + 4] ;; edi <- bitmap pixel at (srcX, srcY)
	cmp dl, trans
	je incY						;; bitmap pixel (srcX, srcY) is not transparent

	INVOKE DrawPixel, eax, edi, edx

incY:
	inc ecx						;; dstY++
evalY:
	cmp ecx, dst				;; if dstY < dstHeight, enter loop
	jl doY
	inc ebx						;; dstX++
evalX:
	cmp ebx, dst				;; if dstX < dstWidth, enter loop
	jl doX

	ret 			; Don't delete this line!!!
RotateBlit ENDP



END
