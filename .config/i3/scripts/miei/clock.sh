#!/usr/bin/bash
a=1
path=~/.config/i3/scripts/miei/clock.sh

change_var () {
if [ $a == 0 ]; then
	sed -i '2d' $path 
	sed -i '2ia=1' $path

	a=1 
	return 1
fi
if [ $a == 1 ]; then
        sed -i '2d' $path
	sed -i '2ia=0' $path
        a=0
	return 0
fi
}

if [ $BLOCK_BUTTON == 1 ]; then
	change_var
fi

if [ $a == 0 ]; then
	date '+%d %b %H:%M' 
fi

if [ $a == 1 ]; then
	date '+%H:%M'                                                                              
fi
