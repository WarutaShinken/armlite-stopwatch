# Challenges

* ARMlite doesn't let me directly output numbers without spacing, so I had to use `.WriteChar`
for printing time values.
* ~~I could use the ASCII codes 48 to 57, which represent digit characters 0 to 9, in the internal counter logic, but that would go against the concept of functional decomposition.~~<br>
  Actually, would it? It would probably just mean that I'm using ASCII values in my increment logic as well.
* In order to not use more registers than are available, I decided to use a single register/word to store the 4 digits in packed time format.<br>
  This simplified the usage of functions that take and return time values.
* Setting the clock interrupt period before enabling interrupts causes a clock interrupt to happen immediately, but there's a 1 clock interrupt period delay (1 second in this case) before that when it's the other way around, so I had to manually make the unpause logic print the current time.
* Because assembly doesn't have nested code blocks for conditional statements and I'm not supposed to use global variables with functions (with the exception of interrupt handlers which have dedicated global registers), making the code organised was a challenge.<br>
  Spaghetti code is usually avoided by not using `goto` statements, but when branch instructions are essentially `goto` statements, this was not an option.
* ARMlite lacking simple conditional branch instructions for `>=` and `<=` despite real ARM implementations having them, made coding conditional statements more annoying.
* The split time array has to be shifted to the right for every new split time recorded due to a shortcoming in split time handling and a lack of time to fix it (I had a deadline to adhere to).