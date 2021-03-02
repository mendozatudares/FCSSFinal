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

;; Has sounds
include \masm32\include\windows.inc
include \masm32\include\winmm.inc
includelib \masm32\lib\winmm.lib


.DATA

;; If you need to, you can place global variables here
    ;; player initialization
    PlayerSpeed = 0f000h            ;; player speed
    PlayerRotation = 51471/2        ;; player rotation speed
    Player SPRITE <640/2, 480/2>    ;; player sprite, start at center
    PlayerAnimation DWORD OFFSET fighter_000, OFFSET fighter_001, OFFSET fighter_002
    AnimationFrame BYTE 0           ;; current frame for player animation

    ;; asteroid initialization
    AsteroidSpeed = 800h            ;; asteroid acceleration
    ;; array of asteroids to work with, initially all valid
    Asteroids SPRITE <430, 67,  51471/2,,, 1000h,, OFFSET asteroid_000>,
                     <75,  212, 51471,,,   2000h,, OFFSET asteroid_000>,
                     <3,   254, 51471*2,,, 1000h,, OFFSET asteroid_000>,
                     <480, 304, 51471*3,,, 1000h,, OFFSET asteroid_000>,
                     <580, 100, 51471*3,,, 1000h,, OFFSET asteroid_000>

    ;; missiles initialization
    PI_HALF = 102943                ;; PI / 2 constant
    MissileSpeed = 100000h          ;; max speed for missiles
    ;; array of missiles to work with, initially all invalid
    Missiles SPRITE 16 DUP(<-100, -100,,,,, 1, OFFSET nuke_000>)
    CurrentMissile BYTE 0   ;; current missile for firing

    ;; game state initialization
    KeyWait = 4             ;; time to wait between key presses (fire and pause)
    GameState DWORD 1       ;; initially start in paused state
    CanPause BYTE 1         ;; boolean for if pausing is allowed
    SinceFire DWORD 0       ;; time since last fire

    ;; text and sound initialization
    StartString BYTE "Welcome! Press P to Play", 0
    InstrString BYTE "WASD to move, <- and -> to turn, Space to fire, P to pause", 0
    WinnrString BYTE "YOU WIN!", 0
    LoserString BYTE "GAME OVER", 0
    MissleSound BYTE "laser_shot_1.wav", 0
    PlayerSound BYTE "explosion_8.wav", 0

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

HandlePause PROC

    cmp KeyPress, VK_P          ;; check if key was pressed
    jne notPressed              ;; if not, enable pausing
    cmp CanPause, 1             ;; check if pausing enabled
    jne returnPause             ;; if p presssed but pausing not enabled, just return
    mov CanPause, 0             ;; if p pressed and can pause, disable pausing
    xor GameState, 1            ;; cycle pause state
    jmp returnPause             ;; return

notPressed:
    mov CanPause, 1             ;; if p not pressed, enable pausing
returnPause:
    ret
HandlePause ENDP

HandleWin PROC

    xor ecx, ecx                ;; start at index 0
    mov edi, OFFSET Asteroids   ;; get starting address of asteroids array
    jmp cond
do:
    lea eax, [edi + ecx]        ;; get asteroid for checking state
    cmp (SPRITE PTR [edi + ecx]).state, 0
    je returnHandleWin          ;; if any asteroid is still valid, we have not won
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Asteroids * SIZEOF SPRITE
    jl do                       ;; check next asteroid

    or GameState, 2             ;; done with loop, all asteroids invalid, we win
    ;; display you win text
    INVOKE DrawStr, OFFSET WinnrString, 285, 240, 255

returnHandleWin:
    ret
HandleWin ENDP

HandleLose PROC

    cmp Player.state, 0         ;; check if player is still valid
    je returnHandleLose
    or GameState, 2             ;; player is not valid, we lost

    ;; display game over text and play player explosion sound
    INVOKE DrawStr, OFFSET LoserString, 285, 240, 255
    INVOKE PlaySound, OFFSET PlayerSound, 0, SND_ASYNC

returnHandleLose:
    ret
HandleLose ENDP

HandleOutOfBounds PROC sprite:PTR SPRITE

    mov eax, sprite

    cmp (SPRITE PTR [eax]).xPos, 640    ;; check if sprite is too far right
    jl checkX
    mov (SPRITE PTR [eax]).xPos, 0      ;; if so, wrap around to left side
checkX:
    cmp (SPRITE PTR [eax]).xPos, 0      ;; check if sprite is too far left
    jge checkY
    mov (SPRITE PTR [eax]).xPos, 640    ;; if so, wrap around to right side

checkY:
    cmp (SPRITE PTR [eax]).yPos, 480    ;; check if sprite is too far down
    jl _checkY
    mov (SPRITE PTR [eax]).yPos, 0      ;; if so, wrap around to top side
_checkY:
    cmp (SPRITE PTR [eax]).yPos, 0      ;; check if sprite is too far up
    jge returnOutOfBounds
    mov (SPRITE PTR [eax]).yPos, 480    ;; if so, wrap around to bottom side

returnOutOfBounds:
    ret
HandleOutOfBounds ENDP

CheckOutOfBounds PROC sprite:PTR SPRITE

    mov eax, sprite

    cmp (SPRITE PTR [eax]).xPos, 640    ;; check if sprite is too far right
    jl checkX
    jmp true                            ;; if so, return true
checkX:
    cmp (SPRITE PTR [eax]).xPos, 0      ;; check if sprite is too far left
    jge checkY
    jmp true                            ;; if so, return true

checkY:
    cmp (SPRITE PTR [eax]).yPos, 480    ;; check if sprite is too far down
    jl _checkY
    jmp true                            ;; if so, return true
_checkY:
    cmp (SPRITE PTR [eax]).yPos, 0      ;; check if sprite is too far up
    jge false
    jmp true                            ;; if so, return true

false:
    mov eax, 0      ;; all checks false, return false
    ret
true:
    mov eax, 1      ;; a check was true, retunr true
    ret
CheckOutOfBounds ENDP

UpdateAsteroid PROC USES esi asteroid:PTR SPRITE

    mov esi, asteroid

    mov eax, (SPRITE PTR [esi]).xPos
    cmp eax, Player.xPos                ;; compare asteroid x coord to player x coord
    jl addGravX
    sub (SPRITE PTR [esi]).xVel, AsteroidSpeed  ;; if asteroid to right of player, accelerate left
    jmp gravY
addGravX:
    add (SPRITE PTR [esi]).xVel, AsteroidSpeed  ;; if asteroid to left of player, accelerate right

gravY:
    mov eax, (SPRITE PTR [esi]).yPos
    cmp eax, Player.yPos                ;; compare asteroid y coord to player y coord
    jl addGravY
    sub (SPRITE PTR [esi]).yVel, AsteroidSpeed  ;; if asteroid below player, accelerate upwards
    jmp updateAsteroid
addGravY:
    add (SPRITE PTR [esi]).yVel, AsteroidSpeed  ;; if asteroid above player, accelerate downwards

updateAsteroid:
    mov eax, (SPRITE PTR [esi]).rVel
    add (SPRITE PTR [esi]).angle, eax   ;; turn asteroid acoording to its constant rotational velocity

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

    xor ecx, ecx                        ;; start with first asteroid
    mov edi, OFFSET Asteroids           ;; get asteroid array
    jmp cond
do:
    mov eax, (SPRITE PTR [edi + ecx]).state     ;; check if asteroid is valid
    test eax, eax
    jg incr                             ;; if not, skip update & draw

    lea eax, [edi + ecx]
    INVOKE UpdateAsteroid, eax          ;; update current asteroid

    ;; draw current asteroid
    INVOKE RotateBlit, (SPRITE PTR [edi + ecx]).bitmap, 
                       (SPRITE PTR [edi + ecx]).xPos, 
                       (SPRITE PTR [edi + ecx]).yPos, 
                       (SPRITE PTR [edi + ecx]).angle
incr:
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Asteroids * SIZEOF SPRITE
    jl do                               ;; if not done, update & draw next asteroid

    ret
UpdateAsteroids ENDP

UpdateMissiles PROC USES ecx edi

    xor ecx, ecx                        ;; start with first missile
    mov edi, OFFSET Missiles            ;; get missiles array
    jmp cond
do:
    lea eax, [edi + ecx]
    INVOKE CheckOutOfBounds, eax        ;; check if missile has gone out of bounds
    test eax, eax
    jz continue                         ;; if not, continue
    mov (SPRITE PTR [edi + ecx]).state, 1
    jmp incr                            ;; otherwise, invalidate it and move on

continue:
    mov eax, (SPRITE PTR [edi + ecx]).state
    test eax, eax                       ;; check if missile is valid
    jg incr                             ;; if not, skip it

    mov eax, (SPRITE PTR [edi + ecx]).xVel
    adc eax, 7fffh
    sar eax, 16                                   ;; round missile's x velocity to nearest whole number
    add (SPRITE PTR [edi + ecx]).xPos, eax        ;; add rounded x velocity to missile's x position

    mov eax, (SPRITE PTR [edi + ecx]).yVel
    adc eax, 7fffh
    sar eax, 16                                   ;; round missile's y velocity to nearest whole number
    add (SPRITE PTR [edi + ecx]).yPos, eax        ;; add rounded y velocity to missile's x position

    ;; draw current missile
    INVOKE BasicBlit, (SPRITE PTR [edi + ecx]).bitmap, 
                      (SPRITE PTR [edi + ecx]).xPos,
                      (SPRITE PTR [edi + ecx]).yPos
incr:
    add ecx, SIZEOF SPRITE
cond:
    cmp ecx, LENGTHOF Missiles * SIZEOF SPRITE
    jl do                       ;; if not done, update & draw next missile

    ret
UpdateMissiles ENDP

Fire PROC USES ecx edx edi

    movzx edi, CurrentMissile       ;; get index of missile to fire
    mov eax, SIZEOF SPRITE
    imul edi, eax                   ;; multiply by sprite size to index array
    add edi, OFFSET Missiles        ;; get address of missile sprite

    mov eax, Player.xPos            ;; move missile to player's location
    mov (SPRITE PTR [edi]).xPos, eax
    mov eax, Player.yPos
    mov (SPRITE PTR [edi]).yPos, eax

    mov eax, Player.angle           ;; get player's angle
    sub eax, PI_HALF                ;; get angle that player is facing
    INVOKE FixedCos, eax            ;; eax <- cos(player angle)
    mov edx, MissileSpeed
    imul edx                        ;; edx:eax <- speed * cos(player angle)
    shl edx, 16
    shr eax, 16
    or edx, eax                     ;; get 32-bit fxpt form of result
    mov (SPRITE PTR [edi]).xVel, edx    ;; missile's xVel = speed * cos(player angle)

    mov eax, Player.angle           ;; get player's angle
    sub eax, PI_HALF                ;; get angle that player is facing
    INVOKE FixedSin, eax            ;; eax <- sin(player angle)
    mov edx, MissileSpeed
    imul edx                        ;; edx:eax <- speed * sin(player angle)
    shl edx, 16
    shr eax, 16
    or edx, eax                     ;; get 32-bit fxpt form of result
    mov (SPRITE PTR [edi]).yVel, edx    ;; missile's yVel = speed * sin(player angle)


    mov (SPRITE PTR [edi]).state, 0     ;; indicate missile is now in valid state

    ;; play missile fire sound
    INVOKE PlaySound, OFFSET MissleSound, 0, SND_ASYNC

    add CurrentMissile, 1
    and CurrentMissile, 15

    ret
Fire ENDP

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

UpdatePlayer PROC

    mov eax, Player.state       ;; check player state
    test eax, eax
    jg returnUpdatePlayer       ;; if player state > 0, no update
    
    INVOKE UpdatePlayerAnimation    ;; update player animation

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
    cmp SinceFire, KeyWait      ;; check if enough time has passed since last fire
    jl updatePlayer             ;; if not, dont check for space
    cmp KeyPress, VK_SPACE      ;; check if space was pressed
    jne updatePlayer
    mov SinceFire, 0            ;; reset time since last fire
    INVOKE Fire                 ;; space pressed, fire a missile
    jmp updatePlayer

rotateRight:
    add Player.angle, PlayerRotation    ;; if right arrow key was pressed, subtract from player's angle
    jmp updatePlayer
rotateLeft:
    sub Player.angle, PlayerRotation    ;; if left arrow key was pressed, add to player's angle
    jmp updatePlayer

down:
    add Player.yVel, PlayerSpeed    ;; if s was pressed, add to player's y velocity
    jmp updatePlayer
up:
    sub Player.yVel, PlayerSpeed    ;; if w was pressed, subtract from player's y velocity
    jmp updatePlayer
right:
    add Player.xVel, PlayerSpeed    ;; if d was pressed, add to player's x velocity
    jmp updatePlayer
left:
    sub Player.xVel, PlayerSpeed    ;; if a was pressed, subtract from player's x velocity

updatePlayer:
    mov eax, Player.xVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's x velocity to nearest whole number
    add Player.xPos, eax        ;; add rounded x velocity to player's x position

    mov eax, Player.yVel
    adc eax, 7fffh
    sar eax, 16                 ;; round player's y velocity to nearest whole number
    add Player.yPos, eax        ;; add rounded y velocity to player's y position

    mov eax, OFFSET Player      ;; wrap player around screen if they move out of bounds
    INVOKE HandleOutOfBounds, eax

    ;; draw player at updated location
    INVOKE RotateBlit, Player.bitmap, 
                       Player.xPos, 
                       Player.yPos, 
                       Player.angle

returnUpdatePlayer:
    ret
UpdatePlayer ENDP

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

HandleIntersections PROC USES ebx ecx edx edi esi

    xor ecx, ecx                        ;; start with first asteroid
    mov edi, OFFSET Asteroids           ;; get asteroids array
    jmp condOuter
doOuter:
    mov eax, (SPRITE PTR [edi + ecx]).state
    test eax, eax                       ;; if state of current asteroid is invalid, move on
    jg incrOuter

    xor ebx, ebx                        ;; start with first missile
    mov esi, OFFSET Missiles            ;; get missiles array
    jmp condInner
doInner:
    mov eax, (SPRITE PTR [esi + ebx]).state
    test eax, eax                       ;; if current missile is invalid, move on
    jg incrInner
    
    ;; check if current asteroid intersected with current missile
    INVOKE CheckIntersect, (SPRITE PTR [edi + ecx]).xPos,
                           (SPRITE PTR [edi + ecx]).yPos,
                           (SPRITE PTR [edi + ecx]).bitmap,
                           (SPRITE PTR [esi + ebx]).xPos,
                           (SPRITE PTR [esi + ebx]).yPos,
                           (SPRITE PTR [esi + ebx]).bitmap
    test eax, eax
    jz incrInner                            ;; if no collision, move on
    mov (SPRITE PTR [edi + ecx]).state, 1   ;; if collision occured, invalidate both asteroid and missile
    mov (SPRITE PTR [esi + ebx]).state, 1

incrInner:
    add ebx, SIZEOF SPRITE                  ;; get index of next missile
condInner:
    cmp ebx, LENGTHOF Missiles * SIZEOF SPRITE
    jl doInner          ;; if haven't checked all missiles with current asteroid, check next

    ;; check if current asteroid intersected with player
    INVOKE CheckIntersect, (SPRITE PTR [edi + ecx]).xPos,
                           (SPRITE PTR [edi + ecx]).yPos,
                           (SPRITE PTR [edi + ecx]).bitmap,
                           Player.xPos,
                           Player.yPos,
                           Player.bitmap
    test eax, eax
    jz incrOuter                            ;; if no collision, move on
    mov (SPRITE PTR [edi + ecx]).state, 1   ;; if collision occured, invalidate asteroid
    mov Player.state, 1                     ;; if collision occured, invalidate player (essentially lose)

incrOuter:
    add ecx, SIZEOF SPRITE                  ;; get index of next asteroid
condOuter:
    cmp ecx, LENGTHOF Asteroids * SIZEOF SPRITE
    jl doOuter          ;; if haven't checked all asteroids, check next

    ret
HandleIntersections ENDP


GamePlay PROC

    INVOKE HandlePause                  ;; check is player has paused or started the game
    cmp GameState, 0
    jne returnGamePlay                  ;; if currently paused or game over, move on

    INVOKE BlankScreen                  ;; clear screen, prep for drawing
    INVOKE DrawStarField                ;; draw stars for background

    INVOKE UpdatePlayer                 ;; update and draw player
    INVOKE UpdateMissiles               ;; update and draw missiles
    INVOKE UpdateAsteroids              ;; update and draw asteroids

    INVOKE HandleWin                    ;; check if player has won
    INVOKE HandleLose                   ;; check if player has lost
    INVOKE HandleIntersections          ;; handle any collisions

returnGamePlay:
    ret         ;; Do not delete this line!!!
GamePlay ENDP

GameInit PROC

    INVOKE DrawStr, OFFSET StartString, 220, 200, 255
    INVOKE DrawStr, OFFSET InstrString, 80, 300, 255

    ret         ;; Do not delete this line!!!
GameInit ENDP

END
