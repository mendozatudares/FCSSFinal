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
    ;; player initialization
    PlayerSpeed = 0f000h            ;; player rotation speed
    PlayerRotation = 51471/2        ;; rotate by pi/8
    Player SPRITE <640/2, 480/2>    ;; player sprite
    PlayerAnimation DWORD OFFSET fighter_000, OFFSET fighter_001, OFFSET fighter_002
    AnimationFrame BYTE 0

    ;; asteroid initialization
    AsteroidSpeed = 1000h
    Asteroids SPRITE <430, 67,  51471/2,,, 1000h,, OFFSET asteroid_000>,
                     <75,  212, 51471,,,   2000h,, OFFSET asteroid_000>,
                     <3,   254, 51471*2,,, 1000h,, OFFSET asteroid_000>,
                     <374, 304, 51471*3,,, 1000h,, OFFSET asteroid_000>

    ;; missiles initialization
    PI_HALF = 102943                ;;  PI / 2
    MissileSpeed = 100000h
    Missiles SPRITE 16 DUP(<-1, -1,,,,, 1, OFFSET nuke_000>)

    ;; game state initialization
    KeyWait = 4
    GameState DWORD 0
    SincePause DWORD 0
    SinceFire DWORD 0
    CurrentMissile BYTE 0

.CODE

BlankScreen PROC USES ecx edi
    ;; this procedure essentially resets the screen's canvas, draws a 640x480
    ;; black rectangle to represent the background

    mov eax, 0                  ;; pixel value to write
    mov ecx, 640*480            ;; number of pixels to zero out
    mov edi, ScreenBitsPtr      ;; destination array
    rep stosb                   ;; repeat store string instruction

    ret
BlankScreen ENDP

UpdatePlayerAnimation PROC USES ebx

    ;; this procedure sets the next frame in the player's animation
    ;; cycles through the bitmaps in PlayerAnimation

    movzx eax, AnimationFrame               ;; get the current frame number
    inc eax                                 ;; set the next frame number
    cmp eax, 6                              ;; 6 = 2 * LENGTHOF PlayerAnimation (for 0.5x speed)
    jl updateFrame                          ;; if next frame number in range, update
    mov eax, 0                              ;; if out of range, set to 0
updateFrame:
    mov AnimationFrame, al                  ;; store the next frame number
    shr al, 1                               ;; next frame number / 2 (for 0.5x speed)
    mov ebx, OFFSET PlayerAnimation         ;; load address for PlayerAnimation array
    mov eax, [ebx + eax * 4]                ;; get address for next player bitmap
    mov Player.bitmap, eax                  ;; update Player.bitmap to hold next bitmap
    
    ret
UpdatePlayerAnimation ENDP

HandlePause PROC

    inc SincePause
    cmp SincePause, KeyWait
    jl returnPause
    cmp KeyPress, VK_P          ;; check if p key was pressed
    jne returnPause
    mov SincePause, 0
    xor GameState, 1            ;; cycle game state

returnPause:
    ret
HandlePause ENDP

HandleWin PROC
    ret
HandleWin ENDP

HandleOutOfBounds PROC sprite:PTR SPRITE

    mov eax, sprite
    cmp (SPRITE PTR [eax]).xPos, 640
    jl checkX
    mov (SPRITE PTR [eax]).xPos, 0
checkX:
    cmp (SPRITE PTR [eax]).xPos, 0
    jge checkY
    mov (SPRITE PTR [eax]).xPos, 640

checkY:
    cmp (SPRITE PTR [eax]).yPos, 480
    jl _checkY
    mov (SPRITE PTR [eax]).yPos, 0
_checkY:
    cmp (SPRITE PTR [eax]).yPos, 0
    jge returnOutOfBounds
    mov (SPRITE PTR [eax]).yPos, 480

returnOutOfBounds:
    ret
HandleOutOfBounds ENDP

UpdateAsteroid PROC USES esi asteroid:PTR SPRITE

    mov esi, asteroid
    mov eax, (SPRITE PTR [esi]).xPos
    cmp eax, Player.xPos
    jl addGravX
    sub (SPRITE PTR [esi]).xVel, AsteroidSpeed
    jmp gravY
addGravX:
    add (SPRITE PTR [esi]).xVel, AsteroidSpeed

gravY:
    mov eax, (SPRITE PTR [esi]).yPos
    cmp eax, Player.yPos
    jl addGravY
    sub (SPRITE PTR [esi]).yVel, AsteroidSpeed
    jmp updateAsteroid
addGravY:
    add (SPRITE PTR [esi]).yVel, AsteroidSpeed

updateAsteroid:
    mov eax, (SPRITE PTR [esi]).rVel
    add (SPRITE PTR [esi]).angle, eax

    mov eax, (SPRITE PTR [esi]).xVel
    adc eax, 7fffh
    sar eax, 16                            ;; round asteroid's x velocity to nearest whole number
    add (SPRITE PTR [esi]).xPos, eax       ;; add rounded x velocity to asteroid's x position

    mov eax, (SPRITE PTR [esi]).yVel
    adc eax, 7fffh
    sar eax, 16                            ;; round asteroid's y velocity to nearest whole number
    add (SPRITE PTR [esi]).yPos, eax       ;; add rounded y velocity to asteroid's y position

    INVOKE HandleOutOfBounds, asteroid
    ret
UpdateAsteroid ENDP

UpdateAsteroids PROC USES ecx edi

    xor ecx, ecx
    mov edi, OFFSET Asteroids
    jmp cond
do:
    lea eax, [edi + ecx]
    INVOKE UpdateAsteroid, eax
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Asteroids * SIZEOF SPRITE
    jl do

    ret
UpdateAsteroids ENDP

DrawAsteroids PROC USES ecx edi

    xor ecx, ecx
    mov edi, OFFSET Asteroids
    jmp cond
do:
    INVOKE RotateBlit, (SPRITE PTR [edi + ecx]).bitmap, (SPRITE PTR [edi + ecx]).xPos, (SPRITE PTR [edi + ecx]).yPos, (SPRITE PTR [edi + ecx]).angle
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Asteroids * SIZEOF SPRITE
    jl do

    ret
DrawAsteroids ENDP

UpdateMissiles PROC USES ecx edi

    xor ecx, ecx
    mov edi, OFFSET Missiles
    jmp cond
do:
    mov eax, (SPRITE PTR [edi + ecx]).xVel
    adc eax, 7fffh
    sar eax, 16                 ;; round missile's x velocity to nearest whole number
    add (SPRITE PTR [edi + ecx]).xPos, eax        ;; add rounded x velocity to missile's x position

    mov eax, (SPRITE PTR [edi + ecx]).yVel
    adc eax, 7fffh
    sar eax, 16                 ;; round missile's y velocity to nearest whole number
    add (SPRITE PTR [edi + ecx]).yPos, eax        ;; add rounded y velocity to missile's x position
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Missiles * SIZEOF SPRITE
    jl do

    ret
UpdateMissiles ENDP

DrawMissiles PROC USES ecx edi

    xor ecx, ecx
    mov edi, OFFSET Missiles
    jmp cond
do:
    INVOKE BasicBlit, (SPRITE PTR [edi + ecx]).bitmap, (SPRITE PTR [edi + ecx]).xPos, (SPRITE PTR [edi + ecx]).yPos
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Missiles * SIZEOF SPRITE
    jl do

    ret
DrawMissiles ENDP

Fire PROC USES ecx edx edi

    movzx edi, CurrentMissile
    mov eax, SIZEOF SPRITE
    imul edi, eax
    add edi, OFFSET Missiles

    mov eax, Player.xPos
    mov (SPRITE PTR [edi]).xPos, eax
    mov eax, Player.yPos
    mov (SPRITE PTR [edi]).yPos, eax

    mov eax, Player.angle
    sub eax, PI_HALF
    INVOKE FixedCos, eax
    mov edx, MissileSpeed
    imul edx
    shl edx, 16
    shr eax, 16
    or edx, eax
    mov (SPRITE PTR [edi]).xVel, edx

    mov eax, Player.angle
    sub eax, PI_HALF
    INVOKE FixedSin, eax
    mov edx, MissileSpeed
    imul edx
    shl edx, 16
    shr eax, 16
    or edx, eax
    mov (SPRITE PTR [edi]).yVel, edx

    add CurrentMissile, 1
    and CurrentMissile, 15

    ret
Fire ENDP

HandleControls PROC

    cmp KeyPress, VK_W          ;; check if w key was pressed
    je up
    cmp KeyPress, VK_A          ;; check if a key was pressed
    je left
    cmp KeyPress, VK_D          ;; check if d key was pressed
    je right
    cmp KeyPress, VK_S          ;; check if s key was pressed
    je down

    cmp KeyPress, VK_LEFT       ;; check if left arrow key was pressed
    je rotateLeft
    cmp KeyPress, VK_RIGHT      ;; check if right arrow key was pressed
    je rotateRight

    inc SinceFire
    cmp SinceFire, KeyWait
    jl updatePlayer
    cmp KeyPress, VK_SPACE      ;; check if space was pressed
    jne updatePlayer
    mov SinceFire, 0
    INVOKE Fire
    jmp updatePlayer

rotateRight:
    add Player.angle, PlayerRotation     ;; if right arrow key was pressed, subtract from player's angle
    jmp updatePlayer
rotateLeft:
    sub Player.angle, PlayerRotation     ;; if left arrow key was pressed, add to player's angle
    jmp updatePlayer

down:
    add Player.yVel, PlayerSpeed     ;; if s was pressed, add to player's y velocity
    jmp updatePlayer
up:
    sub Player.yVel, PlayerSpeed     ;; if w was pressed, subtract from player's y velocity
    jmp updatePlayer
right:
    add Player.xVel, PlayerSpeed     ;; if d was pressed, add to player's x velocity
    jmp updatePlayer
left:
    sub Player.xVel, PlayerSpeed     ;; if a was pressed, subtract from player's x velocity

updatePlayer:
    mov eax, Player.xVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's x velocity to nearest whole number
    add Player.xPos, eax        ;; add rounded x velocity to player's x position

    mov eax, Player.yVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's y velocity to nearest whole number
    add Player.yPos, eax        ;; add rounded y velocity to player's y position

    mov eax, OFFSET Player
    INVOKE HandleOutOfBounds, eax

returnControls:
    ret
HandleControls ENDP

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

HandleIntersections PROC
    ret
HandleIntersections ENDP


GamePlay PROC

    INVOKE HandlePause
    INVOKE HandleIntersections
    INVOKE HandleWin

    cmp GameState, 0
    jne returnGamePlay

    INVOKE BlankScreen                  ;; clear screen, prep for drawing
    INVOKE DrawStarField                ;; draw stars for background

    INVOKE HandleControls               ;; handle any input from user
    INVOKE UpdatePlayerAnimation
    INVOKE UpdateAsteroids
    INVOKE UpdateMissiles

sprites:                                ;; draw Asteroid and Player sprites
    INVOKE RotateBlit, Player.bitmap, Player.xPos, Player.yPos, Player.angle
    INVOKE DrawAsteroids
    INVOKE DrawMissiles

returnGamePlay:
    ret         ;; Do not delete this line!!!
GamePlay ENDP

GameInit PROC

    ret         ;; Do not delete this line!!!
GameInit ENDP

END
