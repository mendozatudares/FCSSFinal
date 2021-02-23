; #########################################################################
;
;   trig.asm - Assembly file for CompEng205 Assignment 3
;
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include trig.inc

.DATA

;;  These are some useful constants (fixed point values that correspond to important angles)
PI_HALF = 102943                ;;  PI / 2
PI =  205887                    ;;  PI 
TWO_PI  = 411774                ;;  2 * PI 
PI_INC_RECIP =  5340353         ;;  256 / PI, Use reciprocal to find the table entry for a given angle
                                ;;      (It is easier to use than divison would be)


    ;; If you need to, you can place global variables here
    
.CODE

FixedSin PROC USES ecx edx angle:FXPT
    LOCAL sign:SBYTE
    mov sign, 1

    mov eax, angle              ;; eax <- angle
check_angle:
    cmp eax, 0
    jl add_pi                   ;; if angle < 0, use sin(x + pi) = -sin(x) identity
    cmp eax, PI_HALF
    jl calculate                ;; if angle >= 0 && angle < pi/2, able to calculate
    je return_one               ;; if angle == pi/2, return 1
    cmp eax, PI
    jl sub_from_pi              ;; if pi/2 < angle < pi, use sin(x) = sin(pi - x) identity
sub_pi:
    sub eax, PI                 ;; else, angle > pi, use sin(x - pi) = -sin(x) identity and sub pi from angle
    jmp neg_sign
add_pi:
    add eax, PI                 ;; add pi to angle
neg_sign:
    neg sign                    ;; determine if final result will be negated due to identities
    jmp check_angle             ;; check angle again
return_one:
    mov eax, 65536              ;; return 1
    jmp check_sign
sub_from_pi:
    neg eax                     ;; pi/2 < angle < pi, find corresponding angle pi - x
    add eax, PI

calculate:
    mov ecx, PI_INC_RECIP       ;; ecx <- 256/pi
    mul ecx             ;; edx contains integer index
    xor eax, eax
    mov ax, [SINTAB + 2*edx]    ;; ax <- sin table entry at index i

check_sign:
    cmp sign, 0
    jg done
    neg eax                     ;; multiply result by the determined sign

done:
    ret         ; Don't delete this line!!!
FixedSin ENDP 
    
FixedCos PROC angle:FXPT

    mov eax, PI_HALF
    add eax, angle              ;; cos(x) = sin(x + pi/2)
    INVOKE FixedSin, eax        ;; eax <- result of sin(angle + pi/2)

    ret         ; Don't delete this line!!! 
FixedCos ENDP   
END
