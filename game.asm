; #########################################################################
;
;   game.asm - Assembly file for CompEng205 Assignment 4/5
;   Kevin Mendoza Tudares
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ;; case sensitive

include stars.inc
include lines.inc
include trig.inc
include blit.inc
include game.inc

;; Has keycodes
include keys.inc

;; Has bitmaps
include bitmaps.inc

    
.DATA

;; If you need to, you can place global variables here
    Asteroid Sprite <250, 250,,,,, 0,>      ;; asteroid sprite
    Player Sprite <300, 300,,,,, 0,>        ;; player sprite

    PlayerAnimation DWORD ?, ?, ?           ;; array for player animation
    AnimationFrame BYTE 0

    GameState BYTE 0
    SinceChange DWORD 0
.CODE

UpdatePlayerAnimation PROC USES ebx

    ;; this procedure sets the next frame in the player's animation
    ;; cycles through the bitmaps in PlayerAnimation

    xor eax, eax
    mov al, AnimationFrame                  ;; get the current frame number
    inc eax                                 ;; set the next frame number
    cmp eax, 6                              ;; 6 = 2 * LENGTHOF PlayerAnimation (for 0.5x speed)
    jl updateFrame                          ;; if next frame number in range, update
    mov eax, 0                              ;; if out of range, set to 0
updateFrame:
    mov AnimationFrame, al                  ;; store the next frame number
    shr al, 1                               ;; next frame number / 2 (for 0.5x speed)
    lea ebx, PlayerAnimation                ;; load address for PlayerAnimation array
    mov eax, [ebx + eax * 4]                ;; get address for next player bitmap
    mov Player.bitmap, eax                  ;; update Player.bitmap to hold next bitmap
    
    ret
UpdatePlayerAnimation ENDP

;; Note: You will need to implement CheckIntersect!!!
CheckIntersect PROC USES ebx edi esi oneX:DWORD, oneY:DWORD, oneBitmap:PTR EECS205BITMAP, twoX:DWORD, twoY:DWORD, twoBitmap:PTR EECS205BITMAP 

    mov edi, oneBitmap      ;; store pointers to bitmaps in registers
    mov esi, twoBitmap

    mov eax, (EECS205BITMAP PTR [edi]).dwWidth
    sar eax, 1
    neg eax
    add eax, oneX           ;; eax <- oneX - oneBitmap.dwWidth / 2
    
    mov ebx, (EECS205BITMAP PTR [esi]).dwWidth
    sar ebx, 1
    add ebx, twoX           ;; ebx <- twoX + twoBitmap.dwWidth / 2

    cmp eax, ebx            ;; compare one's left edge to two's right edge
    jg impossible           ;; if one's left edge is to the right of two's right edge, intersection impossible

    add eax, (EECS205BITMAP PTR [edi]).dwWidth
    sub ebx, (EECS205BITMAP PTR [esi]).dwWidth

    cmp eax, ebx            ;; compare one's right edge to two's left edge
    jl impossible           ;; if one's right edge is to the left of two's left edge, intersection impossible

    mov eax, (EECS205BITMAP PTR [edi]).dwHeight
    sar eax, 1
    neg eax
    add eax, oneY           ;; eax <- oneY - oneBitmap.dwHeight / 2

    mov ebx, (EECS205BITMAP PTR [esi]).dwHeight
    sar ebx, 1
    add ebx, twoY           ;; ebx <- twoY + twoBitmap.dwWidth / 2

    cmp eax, ebx            ;; compare one's top edge to two's bottom edge
    jg impossible           ;; if one's top edge is below two's bottom edge, intersection impossible

    add eax, (EECS205BITMAP PTR [edi]).dwHeight
    sub ebx, (EECS205BITMAP PTR [esi]).dwHeight

    cmp eax, ebx            ;; compare one's bottom edge to two's top edge
    jl impossible           ;; if one's bottom edge is above two's top edge, intersection impossible

    mov eax, 1              ;; if all cases passed, then intersection occured
    ret

impossible:
    mov eax, 0              ;; one of the cases failed, no intersection occured
    ret
CheckIntersect ENDP

Fire PROC

    ret
Fire ENDP

HandleControl PROC

    cmp KeyPress, VK_W          ;; check if w key was pressed
    je up
    cmp KeyPress, VK_A          ;; check if a key was pressed
    je left
    cmp KeyPress, VK_D          ;; check if d key was pressed
    je right
    cmp KeyPress, VK_S          ;; check if s key was pressed
    jne update

    add Player.yVel, 0f000h     ;; if s was pressed, add to player's y velocity
    jmp update
up:
    sub Player.yVel, 0f000h     ;; if w was pressed, subtract from player's y velocity
    jmp update
right:
    add Player.xVel, 0f000h     ;; if d arrow was pressed, add to player's x velocity
    jmp update
left:
    sub Player.xVel, 0f000h     ;; if a was pressed, subtract from player's x velocity

update:
    mov eax, Player.xVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's x velocity to nearest whole number
    add Player.xPos, eax        ;; add rounded x velocity to player's x position
    
    mov eax, Player.yVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's y velocity to nearest whole number
    add Player.yPos, eax        ;; add rounded y velocity to player's y position

mouse:
    cmp MouseStatus.buttons, MK_LBUTTON
    jne noMouse
    INVOKE Fire

noMouse:
    ret
HandleControls ENDP

BlankScreen PROC USES ecx edi
    
    ;; this procedure essentially resets the screen's canvas, draws a 640x480
    ;; black rectangle to represent the background

    mov eax, 0                  ;; pixel value to write
    mov ecx, 640*480            ;; number of pixels to zero out
    mov edi, ScreenBitsPtr      ;; destination array
    rep stosb                   ;; repeat store string instruction

    ret
BlankScreen ENDP

HandlePause PROC

    inc SinceChange
    cmp SinceChange, 4
    jl noPause
    cmp KeyPress, VK_P          ;; check if p key was pressed
    jne noPause
    mov SinceChange, 0
    inc GameState
    and GameState, 1            ;; cycle game state

noPause:
    ret
HandlePause ENDP


GamePlay PROC

    INVOKE HandlePause

    cmp GameState, 0
    jne done

    INVOKE BlankScreen                  ;; clear screen, prep for drawing
    INVOKE DrawStarField                ;; draw stars for background

    INVOKE HandleControls               ;; handle any input from user
    INVOKE CheckIntersect, Player.xPos, Player.yPos, Player.bitmap, Asteroid.xPos, Asteroid.yPos, Asteroid.bitmap
    INVOKE UpdatePlayerAnimation        ;; if intersection occured, run player animation

sprites:                                ;; draw basic Asteroid and Player sprites
    INVOKE BasicBlit, Asteroid.bitmap, Asteroid.xPos, Asteroid.yPos
    INVOKE BasicBlit, Player.bitmap, Player.xPos, Player.yPos

done:
    ret         ;; Do not delete this line!!!
GamePlay ENDP

GameInit PROC
    
    lea eax, asteroid_000
    mov Asteroid.bitmap, eax            ;; set Asteroid sprite's bitmap to asteroid_000

    lea eax, fighter_000
    mov Player.bitmap, eax              ;; set Player sprite's bitmap to fighter_000
    mov [PlayerAnimation], eax          ;; load fighter_000 into PlayerAnimation array
    lea eax, fighter_001
    mov [PlayerAnimation + 4], eax      ;; load fighter_001 into PlayerAnimation array
    lea eax, fighter_002
    mov [PlayerAnimation + 8], eax      ;; load fighter_002 into PlayerAnimation array

    ret         ;; Do not delete this line!!!
GameInit ENDP

END
