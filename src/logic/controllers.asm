; One word representation of controller state
INPUT_UP     equ 0x8000
INPUT_DOWN   equ 0x4000
INPUT_LEFT   equ 0x2000
INPUT_RIGHT  equ 0x1000
INPUT_RED    equ 0x0800
INPUT_YELLOW equ 0x0400
INPUT_BLUE   equ 0x0200
INPUT_GREEN  equ 0x0100
INPUT_BUTTON equ 0x000f

; INPUT_BUTTON masks the currently pressed button
;  0 - all released
;  1 - OK
;  2 - Exit
;  3 - Help
;  4 - Learning zone

; Initialize IO to be able to read controllers state
controllers_init:
.scope
	; Set IOC pins configuration
	ld r1, #0b1000100111000000 ; direction - 0 input, 1 output
	st r1, [GPIO_C_DIR]

	st r1, [GPIO_C_ATTRIB] ; attributes - same as direction make output non-inverted and input possibly pulled high/low

	; Debug
	; Copied form Pulkomandy's example, it says it puts IOC8 (CTS A) down to enable controller A
	;  1. Other part of the doc says that controllers are enabled when CTS is high (not down)
	;  2. IOC8 is effectively set high
	; Ideally both controllers should be disabled until they set their RTS bit, and enabled just the time needed to read their input
	;  Better code sample -> https://github.com/sp1187/vsmile-ctrldemo
	;
	; fedc ba98 7654 3210
	; CTRB .Aba PE?l LLLL
	;  LLLL - language
	;     l - show logo animation at boot
	;     ? - unknown
	;     E - audio enable
	;     P - power control
	;     a - controller A Clear To Send
	;     b - controller B Clear To Send
	;     A - controller A Request To Send
	;     B - controller B Request To Send
	;     R - UART Rx
	;     T - UART Tx
	;     C - Controller power (unsure about that)
	;
	;         fedcba9876543210
	;         CTRB_.Aba_PE?l_LLLL
	ld r1, #0b1111_0111_0111_1111
	st r1, [GPIO_C_DATA]

	// Enable Uart RX (controller input)
	ld r1, #0xa0
	st r1, [UART_BAUD_LO]
	ld r1, #0xfe
	st r1, [UART_BAUD_HI]

	;NOTE disable interrupts, will check it each frame (certainly a bad idea, but simpler implementation for a first draft
	ld r1, #0b11000000 ; 7: TxEn, 6: RxEn, 5: Mode, 4: MulPro, 3-2: bits per byte, 1: Tx Interrupt Enable, 0: Rx Interrupt Enable
	st r1, [UART_CTRL]

	ld r1, #3
	st r1, [UART_STATUS]

	; UART Tx and Rx in "special" mode
	;NOTE in the example, all values are ORed to ensure consistency, here I hardcode result to avoir reading the instruction set to do an OR
	ld r1, #0x6000 ; previous value | 0x6000 (but no way to know previous value, let's assume zero)
	st r1, [GPIO_C_MASK]

	ld r1, #0b1110100111000000 ; GPIO_C_ATTRIB | 0x6000
	st r1, [GPIO_C_ATTRIB]

	ld r1, #0b1100100111000000 ; GPIO_C_DIR | 0x4000
	st r1, [GPIO_C_DIR]

	; Set controllers state variable to "no button pressed"
	ld r1, #0
	st r1, [controller_a_state]
	st r1, [controller_b_state]

	retf
.ends

; Read message sent by controller A, and update its state variable (to be used by game's logic)
controllers_read_joystick_a:
.scope
	; Check if there is a byte in the RX buffer
	ld r1, [UART_STATUS]
	and r1, #0b00000001
	jnz proceed
		goto end
	proceed:

		; Read message from the controller
		ld r1, [UART_RXBUF]

		; Parse joystic input
		;  Each input is a byte with a "family" nimble and a "value" nimble
		ld r2, #0xf0 ; Get "family" nimble
		and r2, r1

		cmp r2, #0x90 ; Check if it is a color input
		jz color_pressed
		cmp r2, #0xc0 ; Check horizontal axis
		jz horizontal_changed
		cmp r2, #0x80 ; Check vertical axis
		jz vertical_changed
		cmp r2, #0xa0 ; Check buttons
		jz buttons_changed

			unhandled_input:
				retf

			color_pressed:
				; Color, the value nimble contains a bitfield of pressed colors in order red,yellow,blue,green

				; r3,r4 = colors bitfield on the 3rd nimble (as in our one word state representation)
				and r1, #0x000f
				ld r2, #0x0100
				mul.us r1, r2

				; Replace colors bitfield in current controller state
				;   state = (state & 0xf0ff) | r3
				ld r2, [controller_a_state]
				and r2, #0xf0ff
				or r2, r3
				st r2, [controller_a_state]
				retf

			buttons_changed:
				; r1 = button pressed in the lowest nimble
				and r1, #0x000f

				; Replace button pressed in current controller state
				ld r2, [controller_a_state]
				and r2, #0xfff0
				or r2, r1
				st r2, [controller_a_state]
				retf

			horizontal_changed:
				; Horizontal value - 0 means neutral, B to F means left, 3 to 7 means right

				and r1, #0x000f
				jz horizontal_neutral
				and r1, #0x0008
				jz right

					left:
						ld r1, [controller_a_state]
						or r1, #INPUT_LEFT
						and r1, #~INPUT_RIGHT
						st r1, [controller_a_state]
						retf

					right:
						ld r1, [controller_a_state]
						and r1, #~INPUT_LEFT
						or r1, #INPUT_RIGHT
						st r1, [controller_a_state]
						retf

					horizontal_neutral:
						ld r1, [controller_a_state]
						and r1, #~INPUT_LEFT
						and r1, #~INPUT_RIGHT
						st r1, [controller_a_state]
						retf

			vertical_changed:
				; Vertical value - 0 means neutral, B to F means down, 3 to 7 means top

				and r1, #0x000f
				jz vertical_neutral
				and r1, #0x0008
				jz up

					down:
						ld r1, [controller_a_state]
						or r1, #INPUT_DOWN
						and r1, #(~INPUT_UP)&0xffff
						st r1, [controller_a_state]
						retf

					up:
						ld r1, [controller_a_state]
						and r1, #~INPUT_DOWN
						or r1, #INPUT_UP
						st r1, [controller_a_state]
						retf

					vertical_neutral:
						ld r1, [controller_a_state]
						and r1, #~INPUT_DOWN
						and r1, #(~INPUT_UP)&0xffff
						st r1, [controller_a_state]
						retf
	end:
	retf
.ends
