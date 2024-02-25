ANIMATION_STATE_SIZE equ 5
ANIMATION_STATE_COUNTER equ 0
ANIMATION_STATE_LAST_TILE equ 1
ANIMATION_STATE_CURRENT_TILE equ 2
ANIMATION_STATE_FIRST_TILE equ 3
ANIMATION_STATE_FRAMERATE_LIMITER equ 4

; Init an animation
;  bp - animation's state address
;  r1 - animation's info address
animation_init:
.scope
	; nb frames skipped between steps
	ld r2, [r1++]
	st r2, [bp + ANIMATION_STATE_COUNTER]
	st r2, [bp + ANIMATION_STATE_FRAMERATE_LIMITER]

	; animation's first tile
	ld r2, [r1++]
	st r2, [bp + ANIMATION_STATE_FIRST_TILE]
	st r2, [bp + ANIMATION_STATE_CURRENT_TILE]

	; animation's last tile
	ld r2, [r1++]
	st r2, [bp + ANIMATION_STATE_LAST_TILE]

	retf
.ends

; Advance animation
;  bp - Animation's state address
animation_tick:
.scope
	ld r1, [bp + ANIMATION_STATE_COUNTER]
	sub r1, #1
	st r1, [bp + ANIMATION_STATE_COUNTER]
	cmp r1, #0
	jnz ok
		; Reset counter
		ld r1, [bp + ANIMATION_STATE_FRAMERATE_LIMITER]
		st r1, [bp + ANIMATION_STATE_COUNTER]

		; Change anim frame
		ld r1, [bp + ANIMATION_STATE_CURRENT_TILE]
		add r1, #1
		st r1, [bp + ANIMATION_STATE_CURRENT_TILE]
		cmp r1, [bp + ANIMATION_STATE_LAST_TILE]
		jnz last_tile_set
			; We gone past the end, loop
			ld r1, [bp + ANIMATION_STATE_FIRST_TILE]
			st r1, [bp + ANIMATION_STATE_CURRENT_TILE]
		last_tile_set:
	ok:
	retf
.ends

; Show animation on screen
;  bp - animation's state address
;  r1 - animation's position X
;  r2 - animation's position Y
animation_display:
.scope
	pos_z equ 1
	sprites_palette equ 1

	ld r3, [bp + ANIMATION_STATE_CURRENT_TILE]
	st r3, [PPU_SPRITE_TILE(0)]

	st r1, [PPU_SPRITE_X(0)]
	st r2, [PPU_SPRITE_Y(0)]

	ld r1, #(pos_z << 12) | (sprites_palette << 8) | (SPRITE_SIZE_64 << 6) | (SPRITE_SIZE_64 << 4) | SPRITE_COLOR_DEPTH_4
	st r1, [PPU_SPRITE_ATTR(0)]

	retf
.ends
