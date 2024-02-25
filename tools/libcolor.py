#!/usr/bin/env python
import sys

# Convert colors to V.Smile color space (5 bits per pixel)

def c(orig):
	return orig // (2**3)

def convert(color):
	if isinstance(color, str) and len(color) == 6:
		# Hex color "RRGGBB"
		return (
			c(int(color[0:2], 16)),
			c(int(color[2:4], 16)),
			c(int(color[4:6], 16))
		)
	if isinstance(color, tuple) and len(color) == 3:
		# (R, G, B) one byte each
		return (
			c(color[0]),
			c(color[1]),
			c(color[2])
		)
	assert False, 'unknown color scheme'
