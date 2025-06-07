#!/usr/bin/env python

import argparse
import json
import os
import pathlib
import struct
import subprocess
import textwrap
import tiled
import tomllib

# Parse command line
parser = argparse.ArgumentParser(description='Compile a .tmx file of 512x256 pixels to a background data file ready to be included.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('index-file', help='Index file containing the list of backgrounds')
parser.add_argument('dst-dir', help='Directory to produce compiled result')
args = parser.parse_args()

index_file_path = getattr(args, 'index-file')
dst_dir = getattr(args, 'dst-dir')

project_root = (pathlib.Path(os.path.dirname(__file__)) / '..').resolve()

# Parse index file
with open(index_file_path, 'rb') as index_file:
	index = tomllib.load(index_file)

assert 'background' in index, "need at least a background in the index"
backgrounds = index.get('backgrounds', [])

# Compile all backgrounds
for background in backgrounds:
	# Parse background properties
	#  source: path to a .tmx file of 512x256 pixels
	#  name:        (deduced from source file) the name of the background
	#  bit_depth:   (deduced from source file) bits per pixel
	#  tile_width:  (deduced from source file) width of a tile (in pixels)
	#  tile_hieght: (deduced from source file) height of a tile (in pixels)
	#  map_width:   (deduced from source file) width of the map (in tiles)
	#  map_height:  (deduced from source file) height of the map (in tiles)
	src_file = project_root / pathlib.Path(background['source'])

	# Sanity checks on Tiled file
	tiled_map = tiled.load(src_file)

	tile_width = tiled_map['tilewidth']
	tile_height = tiled_map['tileheight']
	map_width = tiled_map['width']
	map_height = tiled_map['height']
	assert map_width * tile_width == 512, f'Bagrounds are 512 pixels larges, this tilemap is {map_width}x{tile_width}={map_width * tile_width} pixels large'

	bit_depth = tiled.prop(tiled_map, 'bit_depth')
	assert bit_depth is not None and isinstance(bit_depth, int) and bit_depth in [2, 4, 6, 8], 'The tilemap must have a custom property "bit_depth" of type int which shall be 2, 4, 6 or 8'

	bg1_layer = tiled.get_layer(tiled_map, 'bg1')
	assert bg1_layer is not None, f'The tilemap must have a layer named "bg1"'
	assert bg1_layer['width'] == map_width and bg1_layer['height'] == map_height, f'bg1 layer shal have the same dimension as the tilemap: bg1 is {bg1_layer["width"]}x{bg1_layer["height"]}, map is {map_width}x{map_height}'
	assert len(bg1_layer['data']) == map_width * map_height, f'bg1 data missmatch map size: expected {map_width * map_height} tiles but there are {len(bg1_layer["data"])} tiles'

	assert len(tiled_map['tilesets']) == 1, f'only single tileset is supported, this tilemap references {len(tiled_map["tilesets"])} tilesets'
	tileset = tiled_map['tilesets'][0]

	map_name = os.path.splitext(os.path.basename(src_file))[0]
	assert map_name != '', f'cannot get basename (without extension) of "{src_file}"'
	assert map_name[0] != '.', 'source file cannot be hidden (name begining with a ".")'

	# Compute generated file paths
	built_tileset_filename = os.path.abspath(f'{dst_dir}/{map_name}.built.tileset')
	built_palette_filename = os.path.abspath(f'{dst_dir}/{map_name}.built.palette')
	built_tilemap_filename = os.path.abspath(f'{dst_dir}/{map_name}.built.tilemap')
	built_asm_filename = os.path.abspath(f'{dst_dir}/{map_name}.built.asm')

	project_root = os.path.abspath(os.path.dirname(__file__) + '/..')
	relative_built_tileset_filename = os.path.relpath(built_tileset_filename, project_root)
	relative_built_palette_filename = os.path.relpath(built_palette_filename, project_root)
	relative_built_tilemap_filename = os.path.relpath(built_tilemap_filename, project_root)
	relative_built_asm_filename = os.path.relpath(built_asm_filename, project_root)

	# Generate tileset data
	tile_index_map_filename = '/tmp/mortal_kinder_compile_background_{os.getpid()}_tile_index_map.json'
	tools_dir = os.path.dirname(__file__)
	subprocess.run(
		[
			f'{tools_dir}/tileset_remove_duplicates.py',
			'--tiles-width', str(tile_width),
			'--tiles-height', str(tile_height),
			'--depth', str(bit_depth),
			'--out-tiles', built_tileset_filename,
			'--out-index', tile_index_map_filename,
			'--out-palette', built_palette_filename,
			'--show-stats', 'none',
			tileset['image']
		],
		check=True
	)

	# Generate tilemap
	with open(tile_index_map_filename, 'rt') as tile_index_map_file:
		tile_index_map = json.load(tile_index_map_file)

	try:
		os.unlink(tile_index_map_filename)
	except FileNotFoundError:
		pass

	tilemap = b''
	for i in range(map_width * map_height):
		# We get 1-indexed tile_id from Tiled,
		# convert it to id in the generated tileset with the 0-indexed index map,
		# write it as 1-indexed id on 16-bit binary format
		tiled_tile_index = bg1_layer['data'][i] # 1-indexed
		original_tile_index = tiled_tile_index - 1 # 0-indexed

		tileset_tile_index = tile_index_map.get(str(original_tile_index), original_tile_index) # 0-indexed
		final_tile_index = tileset_tile_index + 1 # 1-indexed

		tilemap += struct.pack('<H', final_tile_index)

	with open(built_tilemap_filename, 'wb') as tilemap_file:
		tilemap_file.write(tilemap)

	# Generate asm file linking all that
	color_depth_bits = {2:0,4:1,6:2,8:3}[bit_depth]
	x_size_bits = {8:0,16:1,32:2,64:3}[tile_width]
	y_size_bits = {8:0,16:1,32:2,64:3}[tile_height]
	with open(built_asm_filename, 'wt') as asm_file:
		asm_file.write(textwrap.dedent(f"""\
			; The graphics data needs to be 64-word aligned
			.align_bits 64*16
			{map_name}_background_tiles:
			.resw ({tile_width}*{tile_height}*{bit_depth})/16 ; tile 0 unusable, not in tileset files
			.binfile "{relative_built_tileset_filename}"

			{map_name}_background_tilemap:
			.binfile "{relative_built_tilemap_filename}"
			{map_name}_background_tilemap_end:

			{map_name}_background_palette:
			.include "{relative_built_palette_filename}"
			{map_name}_background_palette_end:

			; Status bits
			;   bit 0-1: color depth (0 = 2-bit)
			;   bit 2: horizontal flip (0 = no flip)
			;   bit 3: vertical flip (0 = no flip)
			;   bit 4-5: X size (0 = 8 pixels)
			;   bit 6-7: Y size (0 = 8 pixels)
			;   bit 8-11: palette (0 = palette 0, colors 0-3 for 2-bit)
			;   bit 12-13: depth (0 = bottom layer)
			{map_name}_bg_color_depth equ {color_depth_bits}     ; 0=2-bit ; 1=4-bit ; 2=6-bit ; 3=8-bit
			{map_name}_bg_horizontal_flip equ 0 ; 0=no ; 1=yes
			{map_name}_bg_vertical_flip equ 0   ; 0=no ; 1=yes
			{map_name}_bg_x_size equ {x_size_bits}          ; 0=8-pixels ; ...
			{map_name}_bg_y_size equ {y_size_bits}          ; 0=8-pixels ; ...
			{map_name}_bg_palette_number equ 0
			{map_name}_bg_bg_depth equ 0        ; 0=bottom-layer ; ...

			{map_name}_background_info:
			.dw {map_name}_background_tiles >> 6       ; address of tiles (64 words aligned)
			.dw {map_name}_background_tilemap & 0xffff ; address of tilemap (lsw) (msw is assumed to be the same as this structure)
			.dw {map_name}_background_tilemap_end - {map_name}_background_tilemap ; tilemap size (in words)
			.dw ({map_name}_bg_bg_depth<<12) + ({map_name}_bg_palette_number<<8) + ({map_name}_bg_y_size<<6) + ({map_name}_bg_x_size<<4) + ({map_name}_bg_vertical_flip<<3) + ({map_name}_bg_horizontal_flip<<2) + {map_name}_bg_color_depth ; BG attributes
			.dw {map_name}_background_palette & 0xffff
			.dw {map_name}_background_palette_end - {map_name}_background_palette

			; Ensure that all this file is in the same bank
			; (not sure it is really needed, at least it should not be needed)
			.scope
				.set begin_segment = {map_name}_background_tiles & 0x3f_0000
				.set end_segment = $ & 0x3f_0000
				.if begin_segment == end_segment
				.else
					.error "Background data between two banks"
				.endif
			.ends
			"""
		))
