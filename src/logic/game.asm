game_init:
.scope
	; set sprites color palette
	;  0 to 15 can be used by background
	;  16 to 31 are used by player 1 sprites
	ld r2, #color(31, 31, 31) | color_transparent
	st r2, [PPU_COLOR(16+0)]

	ld r2, #color(22, 0, 7)
	st r2, [PPU_COLOR(16+1)]
	ld r2, #color(5, 8, 19)
	st r2, [PPU_COLOR(16+2)]
	ld r2, #color(11, 7, 5)
	st r2, [PPU_COLOR(16+3)]
	ld r2, #color(25, 4, 4)
	st r2, [PPU_COLOR(16+4)]
	ld r2, #color(18, 6, 14)
	st r2, [PPU_COLOR(16+5)]
	ld r2, #color(20, 8, 7)
	st r2, [PPU_COLOR(16+6)]
	ld r2, #color(23, 7, 4)
	st r2, [PPU_COLOR(16+7)]
	ld r2, #color(31, 7, 6)
	st r2, [PPU_COLOR(16+8)]
	ld r2, #color(29, 13, 22)
	st r2, [PPU_COLOR(16+9)]
	ld r2, #color(26, 15, 11)
	st r2, [PPU_COLOR(16+10)]
	ld r2, #color(31, 14, 9)
	st r2, [PPU_COLOR(16+11)]
	ld r2, #color(22, 18, 16)
	st r2, [PPU_COLOR(16+12)]
	ld r2, #color(23, 22, 22)
	st r2, [PPU_COLOR(16+13)]
	ld r2, #color(27, 24, 15)
	st r2, [PPU_COLOR(16+14)]
	ld r2, #color(26, 26, 22)
	st r2, [PPU_COLOR(16+15)]

	; Load background
	call load_background
	call load_background2

	; Players
	call init_player_a

	; Play music
	call audio_init

	ld r1, #0
	ld r2, #1
	call play_music

	retf
.ends

load_background:
.scope
	; DS = background's bank
	and sr, #0b000000_1_1_1_1_111111 ; DS N Z S C CS
	or sr, #(stars_background_info >> 6) & 0b111111_0_0_0_0_000000

	; Set address of tile graphics data
	;  The register only stores the 16 most significant bits of a 22-bit address
	;  lowest 6 bits are expected to be zero, graphics therefore need to be 64-word aligned.
	ld r1, #(stars_background_info & 0xffff) + 0
	ld r2, D:[r1]
	st r2, [PPU_BG1_SEGMENT_ADDR]

	; Copy tilemap from ROM to RAM
	;{
		; R2 = destination address of the copied tilemap (zero-page ensured, it is RAM)
		ld r2, #tilemap

		; R3 = tilemap address (DS bank)
		ld r1, #(stars_background_info & 0xffff) + 1
		ld r3, D:[r1]

		; R4 = tile count
		ld r1, #(stars_background_info & 0xffff) + 2
		ld r4, D:[r1]

		; Copy loop
		copy_tilemap_loop:
			ld r1, D:[r3++]
			st r1, [r2++]
			sub r4, #1
			jnz copy_tilemap_loop
	;}

	; Set color palette
	;{
		; R2 = destination address
		ld r2, #PPU_COLOR(0)

		; R3 = tilemap address (DS bank)
		ld r1, #(stars_background_info & 0xffff) + 4
		ld r3, D:[r1]

		; R4 = words count
		ld r1, #(stars_background_info & 0xffff) + 5
		ld r4, D:[r1]

		; Copy loop
		copy_palette_loop:
			ld r1, D:[r3++]
			st r1, [r2++]
			sub r4, #1
			jnz copy_palette_loop
	;}

	; Set attribute of bg 1
	ld r1, #(stars_background_info & 0xffff) + 3
	ld r2, D:[r1]
	st r2, [PPU_BG1_ATTR] ; first bottom layer

	; Set address of bg 1 tilemap
	ld r2, #tilemap
	st r2, [PPU_BG1_TILE_ADDR]

	; Set control config for bg 1
	;   bit 0: bitmap mode (0 = disable)
	;   bit 1: attribute map mode or register mode (1 = register mode)
	;   bit 2: wallpaper mode (0 = disable)
	;   bit 3: enable bg (1 = enable)
	;   bit 4: horizontal line-specific movement (0 = disable)
	;   bit 5: horizontal compression (0 = disable)
	;   bit 6: vertical compression (0 = disable)
	;   bit 7: 16-bit color mode (0 = disable)
	;   bit 8: blend (0 = disable)
	ld r2, #100001010b
	st r2, [PPU_BG1_CTRL]

	; Use transparent as bg color (compile-background should handle that as bg1 property)
	ld r2, #color(31, 31, 31) | color_transparent
	st r2, [PPU_COLOR(0)]

	retf
.ends

load_background2:
.scope
	; DS = background's bank
	and sr, #0b000000_1_1_1_1_111111 ; DS N Z S C CS
	or sr, #(stars_far_background_info >> 6) & 0b111111_0_0_0_0_000000

	; Set address of tile graphics data
	;  The register only stores the 16 most significant bits of a 22-bit address
	;  lowest 6 bits are expected to be zero, graphics therefore need to be 64-word aligned.
	ld r1, #(stars_far_background_info & 0xffff) + 0
	ld r2, D:[r1]
	st r2, [PPU_BG2_SEGMENT_ADDR]

	; Copy tilemap from ROM to RAM
	;{
		; R2 = destination address of the copied tilemap (zero-page ensured, it is RAM)
		ld r2, #tilemap2

		; R3 = tilemap address (DS bank)
		ld r1, #(stars_far_background_info & 0xffff) + 1
		ld r3, D:[r1]

		; R4 = tile count
		ld r1, #(stars_far_background_info & 0xffff) + 2
		ld r4, D:[r1]

		; Copy loop
		copy_tilemap_loop:
			ld r1, D:[r3++]
			st r1, [r2++]
			sub r4, #1
			jnz copy_tilemap_loop
	;}

	; Set color palette
	;{
		; R2 = destination address
		ld r2, #PPU_COLOR(0)

		; R3 = tilemap address (DS bank)
		ld r1, #(stars_far_background_info & 0xffff) + 4
		ld r3, D:[r1]

		; R4 = words count
		ld r1, #(stars_far_background_info & 0xffff) + 5
		ld r4, D:[r1]

		; Copy loop
		copy_palette_loop:
			ld r1, D:[r3++]
			st r1, [r2++]
			sub r4, #1
			jnz copy_palette_loop
	;}

	; Set attribute of bg 1
	ld r1, #(stars_far_background_info & 0xffff) + 3
	ld r2, D:[r1]
	or r2, #0b01_0000_00_00_0_0_00 ; dd_pppp_hh_ww_v_h_bb
	st r2, [PPU_BG2_ATTR] ; second bottom layer

	; Set address of bg 1 tilemap
	ld r2, #tilemap2
	st r2, [PPU_BG2_TILE_ADDR]

	; Set control config for bg 1
	;   bit 0: bitmap mode (0 = disable)
	;   bit 1: attribute map mode or register mode (1 = register mode)
	;   bit 2: wallpaper mode (0 = disable)
	;   bit 3: enable bg (1 = enable)
	;   bit 4: horizontal line-specific movement (0 = disable)
	;   bit 5: horizontal compression (0 = disable)
	;   bit 6: vertical compression (0 = disable)
	;   bit 7: 16-bit color mode (0 = disable)
	;   bit 8: blend (0 = disable)
	ld r2, #100001010b
	st r2, [PPU_BG2_CTRL]

	; Use transparent as bg color (compile-background should handle that as bg1 property)
	ld r2, #color(31, 31, 31) | color_transparent
	st r2, [PPU_COLOR(0)]

	; Offset BG2
	ld r1, #16
	st r1, [PPU_BG2_SCROLL_Y]

	retf
.ends

init_player_a:
.scope
	; Animation
	ld bp, #player_a_anim
	ld r1, #anim_info
	call animation_init

	; State
	ld r1, #-75
	st r1, [player_a_pos_x]

	retf

	anim_info:
	.dw 8 ; nb frames skipped between steps
	.dw 1 ; animation's first tile
	.dw 4 ; animation's last tile
.ends

game_tick:
.scope
	pos_y equ 0

	; Apply inputs
	ld r1, [controller_a_state]
	and r1, #INPUT_RIGHT
	jz ok_right
		ld r2, [player_a_pos_x]
		add r2, #1
		st r2, [player_a_pos_x]
	ok_right:

	ld r1, [controller_a_state]
	and r1, #INPUT_LEFT
	jz ok_left
		ld r2, [player_a_pos_x]
		sub r2, #1
		st r2, [player_a_pos_x]
	ok_left:

	;TODO move player up and down

	; Scroll background 1
	ld r1, [PPU_BG1_SCROLL_X]
	add r1, #2
	st r1, [PPU_BG1_SCROLL_X]

	;ld r1, [PPU_BG1_SCROLL_Y]
	;add r1, #1
	;st r1, [PPU_BG1_SCROLL_Y]

	; Scroll bg2
	;ld r1, [PPU_BG2_SCROLL_Y]
	;add r1, #1
	;st r1, [PPU_BG2_SCROLL_Y]

	ld r1, [PPU_BG2_SCROLL_X]
	add r1, #1
	st r1, [PPU_BG2_SCROLL_X]

	; Tick animation
	ld bp, #player_a_anim
	call animation_tick

	; Place sprite
	ld bp, #player_a_anim
	ld r1, [player_a_pos_x]
	ld r2, #pos_y
	call animation_display

	retf
.ends
