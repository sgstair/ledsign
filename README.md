# LED Sign Project

The vision for this project is to build an extendable and highly configurable LED panel sign controller.
Core features are to emulate "basic" scrolling LED signs, and provide a way to easily format and display relevant information from web feeds, etc.
Planned modules include stock market, weather, time, arbitrary json content extraction, spectrum analyzer.


# Current Status
* Software to draw and animate a basic sign made of a bunch of elements is basic, but usable.
* Test board firmware and host side control software working pretty well
* FPGA drives LED panel as framebuffer, software can write data via test board currently.
* Once HW is completely verified, will revise to fix errors and post updated PCB designs.

# Next few work items, in no particular order
* Configuration for number of panels being used
* Gamma lookup table in FPGA for better color precision
* Add 32x16 panel scanning mode (probably allow only 32x16 panels to be used in this mode)
* Get USB device support far enough to verify USB will work properly (final requirement before PCB respin + upload)
* USB device support for configuration and writing image data
