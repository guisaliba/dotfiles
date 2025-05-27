<samp>
  <h1 align="center">
    Dotfiles
  </h1>

## Description

Made these dotfiles on a fresh Arch Linux boot. Don't intend for it to be compatible with another distro.

## Technologies

This project was built using:

- bash

## To-do

- [] Reloading i3 config makes Redshift apply blue filter again. `killall redshift` on `redshift.sh` doesn't work as well
- [] Keyboard not being recognized at GRUB boot screen
- [] When an external display gets disconnected, the display recognition does not reset, as if they were still there
- [] Bind display mapping to something like `$mod+Shift+l exec --no-startup-id xrandr --output HDMI-1 --left-of eDP-1 --output HDMI-1 --primary` and `$mod+Shift+u exec_always --no-startup-id xrandr --output HDMI-1 --above eDP-1 --output HDMI-1 --primary` etc.
- [] Set default audio output device for Firefox to Galaxy Buds Pro
- [] `clipse` doesn't save copied content in it's history
- [] Map mouse right click button to double finger press on touchpad

## Usage

You are free to use this repository as you wish. To clone the repository, run the following command:

```
git clone https://github.com/guisaliba/dotfiles.git
```

</samp>
