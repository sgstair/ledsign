# LED Sign Project

Excitement! v1a hardware has been assembled and is working correctly - Next work is to get the USB Device functionality working and then it will be on to more fancy software features!

Interested in seeing more about this project?
* [Youtube channel](https://www.youtube.com/channel/UCL318dWu4VFWcpn52NUiHRw) - More videos about this project will be posted here over time
  * [LED Sign Project update #1](https://www.youtube.com/watch?v=U8zUCaXqkEE)

* [Flickr photostream](https://www.flickr.com/photos/sgstair/) - I'll be adding pictures here
  * [Recent state of rework on the board](https://www.flickr.com/photos/sgstair/23249859330/in/dateposted/)
  * [Shiny, assembled, circuit boards](https://www.flickr.com/photos/sgstair/23342067866/in/dateposted/)
 

## Future
The general vision for this project is to build an extendable and highly configurable LED panel sign controller.
Core features are to emulate "basic" scrolling LED signs, and provide a way to easily format and display relevant information from web feeds, etc.
Planned modules include stock market, weather, time, arbitrary json content extraction, spectrum analyzer.


## Current Status
* Software to draw and animate a basic sign made of a bunch of elements is basic, but usable.
* Test board firmware and host side control software working quite well
* FPGA drives LED panel as framebuffer, software can write data via test board currently.
* Updated and uploaded PCBs - Ordered the rev1a PCBs, assembled, and they've been tested and are working.

## Next few work items, in no particular order
* Configuration for number of panels being used
* Gamma lookup table in FPGA for better color precision
* Add 32x16 panel scanning mode (probably allow only 32x16 panels to be used in this mode)
* USB device support for configuration and writing image data
