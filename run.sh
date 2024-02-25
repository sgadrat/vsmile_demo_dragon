#!/bin/bash

if which VFrown 2> /dev/null 1>&2; then
	VFrown mortal_kinder.bin
elif which mame 2> /dev/null 1>&2; then
	mame vsmile -cart mortal_kinder.bin
else
	echo "no suitable emulator found, please install VFrown or Mame" >&2
	exit 1
fi
