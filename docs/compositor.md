# What is a compositor?

A compositor is responsible for handling the Display, Scaling, Animation, Depth, Shadows, and any Visual effects.

## For Xorg:

- A compositor can be a window manager or be a separate program.

- Not all Xorg window managers are compositing and not all compositors are window managers.

- A Xorg System is very mix'n matchable, You can use a DE and a WM simultaneously - DEs have WMs.

- It doesn't matter what DE, WM, or whatever else you use.

It's like a PC, where you can take parts from another and shove them in, or take it's parts out and use them in another PC. Nice.

## For Wayland:

- A compositor is always a window manager, and vice versa.

- Wayland doesn't necessarily use compositors or window managers.

- You can't customise or modify Wayland systems as extensively as you can with Xorg - talking about the internals, but it depends.

- DEs are hardwired to using their respective WMs (their components)

- Wayland Compositors ('Window Managers') are standalone, they cannot be used in cohesion with another or Compositor or a DE*.*

Wayland is like a Modern Laptop. Works smoothly and is simple to use, not even nearly as clunky, but with the drawbacks of having soldered components made specifically for that machine and must be used in cohesion with whatever else it was already soldered to. - Don't try to Mix'n match Wayland. Nice.
