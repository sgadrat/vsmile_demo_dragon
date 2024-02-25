audio_init:
.scope
	; Configure GPIO (turn on V.Smile audio output)
	ld r2, #0b0000_0000_0110_000
	ld r3, #0b1111_1111_1001_111

	ld r1, [GPIO_C_DATA]
	and r1, r3
	st r1, [GPIO_C_DATA]

	ld r1, [GPIO_C_DIR]
	or r1, r2
	st r1, [GPIO_C_DIR]

	ld r1, [GPIO_C_ATTRIB]
	or r1, r2
	st r1, [GPIO_C_ATTRIB]

	ld r1, #0
	st r1, [GPIO_C_MASK]

	; Initialize SPU, highest volume level, interpolation off
	; uuuuuu_n_l_vv_s_i_p_uu
	; u: unused
	; n: No Interpolation
	; l: LP Enable
	; v: High Volume
	; s: SOF
	; i: Init
	ld r1, #0b0000000_1_1_10_0_1_0_00
	st r1, [SPU_CTRL]

	; Main volume
	; uuuuuuuuu_vvvvvvv
	;  u: unused
	;  v: volume
	ld r1, #0b000000000_1111111
	st r1, [SPU_MAIN_VOLUME]

	retf
.ends

; Play a music on a channel
;  r1 - music index
;  r2 - channel index
play_music:
.scope
	ld r3, #audio_musics & 0xffff
	ld r4, #audio_musics >> 16
	jmp play_asset
	;retf ; useless, jump to subroutine
.ends

; Play an sfx on a channel
;  r1 - music index
;  r2 - channel index
play_sound:
.scope
	ld r3, #audio_sounds & 0xffff
	ld r4, #audio_sounds >> 16
	; retf ; Fallthrough to play_asset
.ends

; Play a music on a channel
;  r1 - music index
;  r2 - channel index
;  r3,r4 - assets table
play_asset:
.scope
	; Channel specific configuration
	;{
		; Push assets table address
		push r4, [sp]
		push r3, [sp]

		; Store channel index
		channel_index equ tmpfield1
		channel_register_offset equ tmpfield2

		st r2, [channel_index]

		ld r3, #16
		mul.us r2, r3
		st r3, [channel_register_offset]

		; Get music address in r2,ds
		;{
			; r2,r3 = (asset_table + 2*music_index)
			add r1, r1

			pop r2, [sp]
			pop r4, [sp]

			add r2, r1
			ld r3, #0
			adc r3, r4

			; r3 = (asset_table + 2*music_index) high bits (in r3's high bits)
			ld r4, #1024
			mul.us r3, r4

			; ds = (asset_table + 2*music_index) high bits
			and sr, #0b000000_1_1_1_1_111111 ; DS N Z S C CS
			or sr, r3

			; push music address lsw
			ld r3, D:[r2++]
			push r3, [sp]

			; ds = music address msw
			ld r1, D:[r2]
			ld r3, #1024
			mul.us r1, r3
			and sr, #0b000000_1_1_1_1_111111 ; DS N Z S C CS
			or sr, r3

			; r2 = music address lsw
			pop r2, [sp]
		;}

		; Set phase of sample
		ld r1, D:[r2++]
		ld r3, [channel_register_offset]
		add r4, r3, #SPU_CH_PHASE_HI(0)
		st r1, [r4]
		ld r1, D:[r2++]
		add r4, r3, #SPU_CH_PHASE_LO(0)
		st r1, [r4]

		ld r1, #0
		add r4, r3, #SPU_CH_PHASE_ACCUM_HI(0)
		st r1, [r4]
		add r4, r3, #SPU_CH_PHASE_ACCUM_LO(0)
		st r1, [r4]

		; Set address and loop point
		ld r1, D:[r2++]
		add r4, r3, #SPU_CH_WAVE_ADDR(0)
		st r1, [r4]

		ld r1, D:[r2++]
		add r4, r3, #SPU_CH_LOOP_ADDR(0)
		st r1, [r4]

		; Channel control
		; ff_tt_llllll_ssssss
		;  u: unused
		;  f: sample format (0=8-bit, 1=16-bit, 2=adpcm, 3=???)
		;  t: Tone Mode (0=software PCM, 1=one shot PCM, 2=Manual loop PCM, 3=???)
		;  l: Loop address segment
		;  s: Sample address segment
		ld r1, D:[r2++]
		add r4, r3, #SPU_CH_MODE(0)
		st r1, [r4]

		; Reset channel wave data to zero point
		ld r1, D:[r2]
		add r4, r3, #SPU_CH_WAVE_DATA_PREV(0)
		st r1, [r4]
		add r4, r3, #SPU_CH_WAVE_DATA(0)
		st r1, [r4]

		; Volume
		; uu_ppppppp_vvvvvvv
		;  u: unused
		;  p: panning (To be determined: is it "0 = full left, 127 = full right"?)
		;  v: volume
		ld r1, #0b00_1000000_1111111
		add r4, r3, #SPU_CH_PAN_VOL(0)
		st r1, [r4]

		; Set envelope volume to full
		; ccccccccc_ddddddd
		;  c: Envelope count
		;  d: Direct data
		ld r1, #0b000000000_1111111
		add r4, r3, #SPU_CH_ENVELOPE_DATA(0)
		st r1, [r4]

		; Set envelope loop (is that value means no loop as we use direct data?)
		; rrrrrrr_aaaaaaaaa
		;  r: Rampdown offset
		;  a: Envelope address offset
		ld r1, #0b0000000_000000000
		add r4, r3, #SPU_CH_ENVELOPE_LOOP_CTRL(0)
		st r1, [r4]
	;}

	; Changes in global audio configuration
	;{
		; Compute channel's masks
		ld r2, #0b0000_0000_0000_0001

		ld r3, [channel_index]
		channel_mask_loop:
			jz end_channel_mask_loop

				ld r4, #0
				add r4, r2 lsl 1
				ld r2, r4

				sub r3, #1
				jmp channel_mask_loop
		end_channel_mask_loop:

		xor r3, r2, #0b1111_1111_1111_1111

		; Disable rampdown, 1 bit per channel
		ld r1, [SPU_ENV_RAMP_DOWN]
		and r1, r3
		st r1, [SPU_ENV_RAMP_DOWN]

		; Channel envelope repeat, 1 bit per channel
		; Actually we never use enveloppe repeat, so there is no real need to reset that bit (it will never be 1)
		;ld r1, [SPU_CHANNEL_REPEAT]
		;and r1, r3
		;st r1, [SPU_CHANNEL_REPEAT]

		; Channel envelope mode, 1 bit per channel
		ld r1, [SPU_CHANNEL_ENV_MODE]
		or r1, r2
		st r1, [SPU_CHANNEL_ENV_MODE]

		; Channel stop, 1 bit per channel
		ld r1, [SPU_CHANNEL_STOP]
		or r1, r2
		st r1, [SPU_CHANNEL_STOP]

		; Channel enable, 1 bit per channel
		ld r1, [SPU_CHANNEL_ENABLE]
		or r1, r2
		st r1, [SPU_CHANNEL_ENABLE]
	;}

	retf
.ends
