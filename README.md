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
* Boots into Tom Pittman's Tiny Basic.
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

## Schematics

Coming soon!

## About the Author

[Nick A. Bild, MS](https://nickbild79.firebaseapp.com/#!/)
