#!/usr/bin/env python

import sys
from PIL import Image

sprite_w = 64
sprite_h = 64
depth = 4 # hardcoded everywhere, TODO make things adaptable so there is just to change this constant

# Read spritesheet
img = Image.open(sys.argv[1])
assert img.mode == 'P', 'input image must be paletized, current mode "{}"'.format(img.mode)

sheet_w = img.size[0]
sheet_h = img.size[1]
assert sheet_w % sprite_w == 0, 'sheet should contain an exact number of sprites'
assert sheet_h % sprite_h == 0, 'sheet should contain an exact number of sprites'
assert sheet_h == sprite_h, 'unhandled multi-row spritesheet'

n_sprites = sheet_w // sprite_w

# Serialize sprites
for sprite_index in range(n_sprites):
	# Get sprite's position on sheet
	sprite_pos_y = 0
	sprite_pos_x = sprite_index * sprite_w

	# Serialize sprite
	#TODO reimplement with libtile, would allow to handle any depth easily
	sprite_blob = b''
	pixel_in_byte = 0
	current_pixel = 0
	for y in range(sprite_h):
		for x in range(sprite_w):
			pixel = img.getpixel((sprite_pos_x+x, sprite_pos_y+y))
			assert pixel >= 0 and pixel < 2**depth, "invalid pixel in {} depth palette: position={}x{} color={}".format(depth, sprite_pos_x+x, sprite_pos_y+y, pixel)
			if pixel_in_byte == 0:
				current_byte = pixel * 16
				pixel_in_byte += 1
			else:
				current_byte += pixel
				sprite_blob += bytes([current_byte])
				pixel_in_byte = 0

	# Output serialized sprite
	sys.stdout.buffer.write(sprite_blob)
