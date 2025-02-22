; Run the code at: https://peterhigginson.co.uk/ARMlite

; Keyboard Controls:
; * P - Start/Pause/Unpause
; * S - Split Time Button
;   * When stopwatch is counting, this will record a split time.
;   * When stopwatch is paused, this will toggle showing the split time.
; * R - Reset
;   * Stops the stopwatch.
;   * Clears the current time.
;   * Clears the split times.
; 
; I hope I don't have to clarify this, but just in case:
; * Blocks of code that begin with a label and end with RET
;   (with or without another label in front of it) are function definitions.
; * Functions follows ABI conventions for register usage.
; * Functions will push and pop extra registers beyond R0-R3 they will be using.
; * Functions will push and pop LR to enable nested function calls.
; * Flags are either 0 (clear/unset) or 1 (raised/set).
; 
; I'm clarifying this above the code so I don't have to do it for every function and flag.
; 
; Throughout the code, I will be storing time values in what I will refer to as
; "packed time format". This stores each digit as a byte in a 32-bit value.
; For example, 12:34 in packed time format is 0x01020304.

; =============================================================================================
; Initialisation Code and Main Loop
; =============================================================================================

	; Interrupt 'Global' Registers
	; R4 - Pending interrupt flag, raised by interrupt handlers.
	; R5 - Pending ticks, incremented by clock interrupt handler.
	; R6 - Pending key press, set by keyboard interrupt handler.
	
	; Main Loop Registers
	; R7  - Clock interrupt period.
	; R8  - Current time, stored in packed time format.
	; R9  - Split time array address.
	; R10 - Split time array size in bytes.
	; R11 - Time selection, determines what time to show when paused.
	;       1 for showing the current time.
	;       0, 4, 8, 12 and 16 for split times 1-5. These are array element offsets.
	
	; Use clock_record as the clock interrupt handler.
	MOV R0, #clock_record
	STR R0, .ClockISR
	
	; Set up keyboard interrupt.
	MOV R0, #keyboard_record ; Use keyboard_record...
	STR R0, .KeyboardISR     ; ...as the keyboard interrupt handler.
	MOV R0, #1
	STR R0, .KeyboardMask    ; Enable the keyboard interrupt.
	
	; Initialise split time array address register.
	MOV R9, #split_times
	
	; Flush output.
	MOV R1, #text_flush
	STR R1, .WriteString
	; Print opening message.
	MOV R1, #opening_message
	STR R1, .WriteString
	
	; Enable interrupts.
	STR R0, .InterruptRegister
main_loop:
	CMP R4, #1            ; Check the pending interrupt flag...
	BLT main_loop         ; ...and skip the loop iteration if it's clear.
	CMP R5, #0            ; Check for pending ticks...
	BGT tick_respond      ; ...and jump to tick_respond if there are any.
	CMP R6, #0x00         ; Check for a pending key press...
	BNE key_press_respond ; ...and jump to key_press_respond if there is one.
	
	B main_loop
key_press_respond:
	CMP R6, #0x50     ; Check if key press is P...
	BEQ pause_respond ; ...and jump to pause_respond if it is.
	CMP R6, #0x53     ; Check if key press is S...
	BEQ split_respond ; ...and jump to split_respond if it is.
	CMP R6, #0x52     ; Check if key press is R...
	BEQ reset_respond ; ...and jump to reset_respond if it is.
	
	B key_press_reset
pause_respond:
	; Jump to pause if the stopwatch isn't paused.
	CMP R7, #0
	BGT pause
	
	; Unpause
	
	; Enable the clock interrupt by setting it to 1000 milliseconds.
	MOV R7, #1000
	STR R7, .ClockInterruptFrequency
	
	; Clock interrupts don't happen immediately after setting .ClockInterruptFrequency
	; if .InterruptRegister was set first, so it is re-printed in the unpause logic.
	MOV R0, R8
	BL time_display
	
	; Reset time selection.
	MOV R11, #0
	
	B key_press_reset
pause:
	; Disable the clock interrupt by setting it to 0.
	MOV R7, #0
	STR R7, .ClockInterruptFrequency
	
	; Show current time.
	MOV R0, R8
	BL time_display
	MOV R0, #paused_indicator
	STR R0, .WriteString
	
	B key_press_reset
reset_respond:
	; Disable the clock interrupt by setting it to 0.
	MOV R7, #0
	STR R7, .ClockInterruptFrequency
	
	MOV R8, #0    ; Clear current time.
	MOV R11, #0   ; Clear time selection.
	
	; Clear split times by setting the array size to 0.
	MOV R10, #0
	
	; Flush output.
	MOV R1, #text_flush
	STR R1, .WriteString
	; Print opening message.
	MOV R0, #opening_message
	STR R0, .WriteString
	
	B key_press_reset
split_respond:
	; Jump to split_record if the stopwatch isn't paused.
	CMP R7, #0
	BGT split_record
	
	; Jump to split_time_toggle if there are recorded split times.
	CMP R10, #0
	BGT split_time_toggle
	
	B key_press_reset
split_time_toggle:
	; Jump to non_split_time_show if the current time is selected.
	CMP R11, #1
	BEQ non_split_time_show
	
	; Show split time.
	LDR R0, [R9 + R11] ; Load the selected split time.
	BL time_display
	MOV R0, #split_time_indicator
	STR R0, .WriteString
	
	; Select the next split time.
	ADD R11, R11, #4
	
	; Skip to key_press_reset if selected split time is within the array.
	CMP R11, R10
	BLT key_press_reset
	
	; Select the current time.
	MOV R11, #1
	
	B key_press_reset
non_split_time_show:
	; Show current time.
	MOV R0, R8
	BL time_display
	MOV R0, #paused_indicator
	STR R0, .WriteString
	
	; Select the first split time.
	MOV R11, #0
	
	B key_press_reset
split_record:
	; Shift array elements to the right.
	
	MOV R1, #12
	MOV R2, #16
	LDR R0, [R9 + R1]
	STR R0, [R9 + R2]
	
	MOV R2, #8
	LDR R0, [R9 + R2]
	STR R0, [R9 + R1]
	
	MOV R1, #4
	LDR R0, [R9 + R1]
	STR R0, [R9 + R2]
	
	LDR R0, [R9]
	STR R0, [R9 + R1]
	
	; Add split time.
	STR R8, [R9]
	
	; Jump to resize_array if array hasn't reached max size.
	CMP R10, #20
	BLT resize_array
	
	B key_press_reset
resize_array:
	ADD R10, R10, #4
key_press_reset:
	; Cleanup after responding to a key press.
	
	; Clear pending key press.
	MOV R6, #0
	; Clear pending interrupt flag.
	MOV R4, #0
	; Re-enable keyboard interrupts.
	MOV R0, #1
	STR R0, .KeyboardMask
	
	B main_loop
tick_respond:
	; Increment time by 1 second.
	MOV R0, R8
	BL time_increment
	MOV R8, R0
	
	; Update interrupt 'globals'.
	SUB R5, R5, #1           ; Decrement pending tick count.
	CMP R5, #0               ; Check if there are no pending ticks...
	BGT interrupt_clear_skip ; ...and jump to interrupt_clear_skip if there are none.
	MOV R4, #0               ; Clear pending interrupt flag.
interrupt_clear_skip:
	; Update displayed time.
	MOV R0, R8
	BL time_display
B main_loop

; =============================================================================================
; Interrupt Handlers
; =============================================================================================

; Clock Interrupt Handler
clock_record:
	MOV R4, #1     ; Raise pending interrupt flag.
	ADD R5, R5, #1 ; Increment pending ticks.
RFE

; Keyboard Interrupt Handler
keyboard_record:
	; Raise pending interrupt flag.
	MOV R4, #1
	
	; Disable keyboard interrupts.
	MOV R6, #0
	STR R6, .KeyboardMask
	
	; Record the key press.
	LDR R6, .LastKey
RFE

; =============================================================================================
; Main Loop-Level Functions
; =============================================================================================

; Increment time by 1 second, resetting after 99:59.
; * Arguments:
;   * R0 - Packed time value.
; * Return Values:
;   * R0 - Updated packed time value.
time_increment:
	PUSH {LR}
	
	MOV R2, R0 ; Return value.
	;   R3     ; Bitwise buffer.
	
	; Increment right seconds digit.
	AND R0, R2, #0xFF
	MOV R1, #10
	BL digit_increment
	; Pack digit.
	MOV R3, #0xFFFFFF00
	AND R2, R2, R3 ; Clear digit.
	ORR R2, R2, R0
	
	; Return if carry flag is clear.
	CMP R1, #1
	BLT time_increment_end
	
	; Increment left seconds digit.
	LSR R0, R2, #8
	AND R0, R0, #0xFF
	MOV R1, #6
	BL digit_increment
	; Pack digit.
	MOV R3, #0xFFFF00FF
	AND R2, R2, R3 ; Clear digit.
	LSL R0, R0, #8
	ORR R2, R2, R0
	
	; Return if carry flag is clear.
	CMP R1, #1
	BLT time_increment_end
	
	; Increment right minutes digit.
	LSR R0, R2, #16
	AND R0, R0, #0xFF
	MOV R1, #10
	BL digit_increment
	; Pack digit.
	MOV R3, #0xFF00FFFF
	AND R2, R2, R3 ; Clear digit.
	LSL R0, R0, #16
	ORR R2, R2, R0
	
	; Return if carry flag is clear.
	CMP R1, #1
	BLT time_increment_end
	
	; Increment left minutes digit.
	LSR R0, R2, #24
	MOV R1, #10
	BL digit_increment
	; Pack digit.
	MOV R3, #0x00FFFFFF
	AND R2, R2, R3 ; Clear digit.
	LSL R0, R0, #24
	ORR R2, R2, R0
	
	; Return if carry flag is clear.
	CMP R1, #1
	BLT time_increment_end
time_increment_end:
	MOV R0, R2 ; Load return value to its return register.
	POP {LR}
RET

; Update displayed time.
; * Arguments:
;   * R0 - Packed time digits.
time_display:
	PUSH {LR}
	
	; R1 - Write buffer.
	
	; Flush output.
	MOV R1, #text_flush
	STR R1, .WriteString
	
	; Print left minutes digit.
	LSR R1, R0, #24
	ADD R1, R1, #48
	STR R1, .WriteChar
	; Print right minutes digit.
	LSR R1, R0, #16
	AND R1, R1, #0xFF
	ADD R1, R1, #48
	STR R1, .WriteChar
	; Print colon.
	MOV R1, #0x3A
	STR R1, .WriteChar
	; Print left seconds digit.
	LSR R1, R0, #8
	AND R1, R1, #0xFF
	ADD R1, R1, #48
	STR R1, .WriteChar
	; Print right seconds digit.
	AND R1, R0, #0xFF
	ADD R1, R1, #48
	STR R1, .WriteChar
	
	POP {LR}
RET

; =============================================================================================
; Helper Functions
; =============================================================================================

; Increments a digit by 1, resetting at the reset value.
; * Arguments:
;   * R0 - Digit value.
;   * R1 - Reset value.
; * Return Values:
;   * R0 - Updated digit value.
;   * R1 - Carry flag.
digit_increment:
	PUSH {LR}
	
	ADD R0, R0, #1          ; Increment digit.
	CMP R0, R1              ; Compare digit with max value...
	MOV R1, #0              ; Clear the carry flag.
	BLT digit_increment_end ; ...return if less than max value.
	
	MOV R0, #0 ; Reset digit to 0.
	MOV R1, #1 ; Set carry flag.
digit_increment_end:
	POP {LR}
RET

; =============================================================================================
; Data Labels
; =============================================================================================

text_flush: .ASCIZ "\n\n\n\n\n" ; Flushes the text output with line breaks when printed.

opening_message: .ASCIZ "Press P to start."
paused_indicator: .ASCIZ " (Paused)"
split_time_indicator: .ASCIZ " (Split Time)"

; Split Time Array
split_times: .BLOCK 20 ; 5 words, 1 for each split time.