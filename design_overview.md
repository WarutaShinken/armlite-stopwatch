# Design Overview

My assembly code follows the following design choices.

## Variables

Most variables are stored entirely in registers, specifically `R4`-`R12`. Other than memory locations for configuring ARMlite interrupts, the only variable that have a memory location assigned to them is the array for recording split times.

Most variables are assigned to dedicated registers to reduce the amount of memory accesses required. The split time array is an exception because:
* It is not accessed often enough to justify consuming registers.<br>
  It's only ever accessed when the S-key is pressed.
* As a 5-element array, it is a collection of 5 words, which requires 5 registers to store.<br>
  The only spare register is `R12`.
* Memory is easier to dynamically iterate through than registers, which is important for an array.

### Main Loop Registers

These register variables are used in the main loop:
* `R7` – Clock interrupt period. Used to:
  * Set .ClockInterruptFrequency for unpausing.
  * Check if the stopwatch is paused or not.
* `R8` – Current time, stored in packed time format.
* `R9` – Split time array address.
* `R10` – Split time array size in bytes.
* `R11` – Time selection, determines what time to show when paused.
  * 1 for showing the current time.
  * 0, 4, 8, 12 and 16 for split times 1-5. These are array element offsets.

## Functions

* Functions follow the following ABI (application binary interface) conventions:
  * `R0` and `R3` are for function arguments.
  * `R0` and `R1` are for return values.
  * `R4`-`R12` must be returned to their original values after a function call completes.<br>
    This involves the use of the stack.
* Functions are called using `BL` and exit with `RET`.<br>
  The link register (`LR`) used by `RET` is `PUSH`ed and `POP`ped to and from the stack to allow returning from nested function calls.

## Interrupts

* Interrupt handlers are made to do a minimal amount of work, only recording to a set of 'global' registers dedicated to them.
  * `R4` records if any interrupt has been recorded.
    * 0 when clear, 1 when set.
    * Cleared once all pending interrupts have been handled.
  * `R5` records the number of clock interrupt events that have occurred.
    * This is decremented every time the register that tracks the current time is incremented.
    * If this register somehow reaches a value larger than 1, the stopwatch will rapidly tick up without delay until it is 0 again.<br>
      This allows the program to keep track of time even if it was somehow too busy to 
  * `R6` records key presses, is equal to `0x00` when clear. Cleared once the key press has been processed.
* Most of the interrupt handling is done in the main loop instead of functions.<br>
  This is because I need to access the interrupt registers to handle them, and accessing global registers inside of functions is bad practice.

## Time Value Format

Time values are stored in what I will refer to as "packed time format".
* This stores each digit as a byte in a 32-bit value.<br>
  For example, 12:34 in packed time format is 0x0<u>1</u>0<u>2</u>0<u>3</u>0<u>4</u>.
* This makes it possible to only use a single register for storing and passing time values to and from functions.
* The complexity of having to pack and unpack these values are limited to the functions `time_increment` and `time_display`.

## Initialisation Section

It has an initialisation section at the top of the document that does the following:
* Sets up the clock and keyboard interrupt.
* Sets the split time array address register.
* Prints the opening message, first printing the `text_flush` label for consistency.
* Enables interrupts.

## Output

When printing something to the output text box:
1. A series of 5 line breaks are printed to flush out older output for clarity.
2. The intended output is printed without a line break, ensuring it's shown at the bottom of the text box.

## Hindsight

In hindsight, I should've made the interrupt flag raises for `R4` happen at the end of the interrupt handlers, so that there is less of a delay in disabling further interrupt handling while recording interrupt data. For example, the keyboard interrupt should disable keyboard interrupts before raising `R4` so that `.LastKey` isn't overwritten before it can be captured.