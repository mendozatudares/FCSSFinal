; #########################################################################
;
;   stars.asm - Assembly file for CompEng205 Assignment 1
;
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive


include stars.inc

.DATA

    ;; If you need to, you can place global variables here

.CODE

DrawStarField proc

    ;; Place your code here
      invoke DrawStar, 150, 200 ;; draws a single star at location (150, 200)
      invoke DrawStar, 23, 430
      invoke DrawStar, 345, 434
      invoke DrawStar, 292, 217
      invoke DrawStar, 452, 422
      invoke DrawStar, 546, 400
      invoke DrawStar, 253, 347
      invoke DrawStar, 392, 419
      invoke DrawStar, 438, 353
      invoke DrawStar, 600, 307
      invoke DrawStar, 576, 376
      invoke DrawStar, 337, 18
      invoke DrawStar, 358, 301
      invoke DrawStar, 281, 167
      invoke DrawStar, 588, 128
      invoke DrawStar, 66, 11
    ret             ; Careful! Don't remove this line
DrawStarField endp



END
