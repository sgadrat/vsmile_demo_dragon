class Tile:
	def __init__(self, size, depth):
		self.depth = depth
		self.size = size
		self.bin = ['0'*depth]*(size[0]*size[1])

	def __eq__(self, other):
		return (
			self.depth == other.depth and
			self.size == other.size and
			self.bin == other.bin
		)

	def set_pixel(self, position, value):
		assert position[0] < self.size[0], f"Tile: set value for pixel out of bound: pixel {position} while size is {self.size}"
		assert position[1] < self.size[1], f"Tile: set value for pixel out of bound: pixel {position} while size is {self.size}"
		assert value < 2**self.depth, f"Tile: set value too large for bit depth: value={value}, depth={self.depth} (mac value is {2**self.depth})"
		pixel_bin = f'{value:b}'.zfill(self.depth)
		pixel_bin_pos = position[1] * self.size[0] + position[0]
		self.bin[pixel_bin_pos] = pixel_bin

	def bin_string(self):
		res = ''
		for pixel in self.bin:
			res += pixel
		return res

def extract_tile(img, position, size, depth):
	"""
	Extract a tile from image
	img - a pillow image in paletized mode
	position (x, y) - position of the tile, in pixels from img's top-left corner
	size (w, h) - size of the tile, in pixels
	depth - bit depth of the tile
	"""
	tile = Tile(size, depth)

	pixel_in_byte = 0
	current_pixel = 0
	for y in range(size[1]):
		for x in range(size[0]):
			pixel = img.getpixel((position[0]+x, position[1]+y))
			assert pixel >= 0 and pixel < 2**depth, "invalid pixel in {} depth palette: position={}x{} color={}".format(depth, position[0]+x, position[1]+y, pixel)
			tile.set_pixel((x, y), pixel)

	return tile

def serialize_tiles(tiles):
	"""
	Serialize a collection of tiles to a bytes object.
	If result is not an integer number of words, it is padded with 0s.
	"""
	# Get binary string
	bin_string = ''
	for tile in tiles:
		bin_string += tile.bin_string()

	# Pad to have an exact number of words
	word_size = 16
	if len(bin_string) % word_size != 0:
		bin_string = bin_string.ljust(len(bin_string) + word_size - (len(bin_string) % word_size), '0')

	# Convert bin string to bytes
	byte_size = 8
	return bytes([int(bin_string[pos*byte_size:pos*byte_size+byte_size], 2) for pos in range(len(bin_string)//byte_size)])
