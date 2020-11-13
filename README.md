# Vectron 65

The Vectron 65 is a 6502 CPU-based breadboard computer.  It supports VGA output, keyboard input, boots into a BASIC interpreter, and has lots of GPIOs.

<p align="center">
<img src="https://raw.githubusercontent.com/nickbild/vectron_65/main/media/basic.gif">
</p>

This computer is a much-upgraded version of my original [Vectron 64 computer](https://github.com/nickbild/vectron_64).

## Specs

* [65C02 CPU](https://en.wikipedia.org/wiki/MOS_Technology_6502) clocked at 8 Mhz.
* 32KB RAM
* 32KB EEPROM
  - Programmable via my [custom Arduino Mega 2560 based platform](https://github.com/nickbild/eeprom_burner_mega).
* 400x300 @ 60Hz VGA output, as 50x30 text mode display.
  - See my [MiniVGA Text Mode](https://github.com/nickbild/fpga_vga_text_mode) project for details.
* PS/2 keyboard support.
* Boots into Tom Pittman's Tiny BASIC.
* 19 GPIOs
* Built with 7400 series logic contemporary with the original 6502 CPU (with the exception of the FPGA-based VGA output).

## Media

YouTube:  
https://www.youtube.com/watch?v=CHY8aZnOKDY

Vectron 65:
![Vectron 65](https://raw.githubusercontent.com/nickbild/vectron_65/main/media/v65_sm.jpg)

Home automation using the GPIOs—who needs a Raspberry Pi? :)
<p align="left">
<img src="https://raw.githubusercontent.com/nickbild/vectron_65/main/media/light_tree.gif">
</p>

EEPROM Burner:
![EEPROM Burner](https://raw.githubusercontent.com/nickbild/vectron_65/main/media/eeprom_burner_sm.jpg)


## Schematics

Coming soon!

## Operation

The operating system source code is available in [os.asm](https://github.com/nickbild/vectron_65/blob/main/os.asm).  Assembly was done with [dasm](https://dasm-assembler.github.io/).  The convenience script, [build.sh](https://github.com/nickbild/vectron_65/blob/main/build.sh) assembles the source and feeds it into [hex_for_mega.py](https://github.com/nickbild/vectron_65/blob/main/hex_for_mega.py) to prepare the data needed for programming the EEPROM with my [Arduino-based EEPROM burner](https://github.com/nickbild/eeprom_burner_mega).  Insert the output from `build.sh` into the `data` array in the Arduino sketch.  Wiring is straightforward—see top of sketch for details.

VGA output is produced with the help of a TinyFPGA BX using my [MiniVGA Text Mode](https://github.com/nickbild/fpga_vga_text_mode) project.  Characters are added to the screen by writing the row and column number to a 65C22 VIA's port A and B, then hitting a latch address with the desired character ASCII code on the data bus.  I would prefer to keep FPGAs out of the design for a 'pure' retro computer, but I have already been down the path of building 7400-series IC based VGA generators (see [Vectron VGA](https://github.com/nickbild/vectron_vga)), and simply do not want that much bulk sitting on my desk.

A second 65C22 VIA handles keyboard input.  Unused VIA port pins are available to use as GPIO.

On powering up the computer and clicking the reset button, a Tiny BASIC prompt is shown on screen.  See the [Tiny BASIC manual](http://www.ittybittycomputers.com/ittybitty/tinybasic/tbuserman.htm) for specifics on this version of BASIC.

## Future Direction

I will most likely have a PCB manufactured in the very near future.  I am just deciding if I want to build any additional functionality into the computer first.

## About the Author

[Nick A. Bild, MS](https://nickbild79.firebaseapp.com/#!/)
