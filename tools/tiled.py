import json
import os
import shutil
import subprocess

def load(input_filename):
	"""
	Return a dict containing the map.

	Can take .json exported by Tiled, or a .tmx (will invoke Tiled to export it to a temporary file)
	"""
	def unlink(filename):
		try:
			os.unlink(filename)
		except FileNotFoundError:
			pass

	map_filename = '/tmp/load_tiled_{os.getpid()}.json'
	tileset_filename = '/tmp/load_tiled_tileset_{os.getpid()}.json'

	try:
		# Ensure to have an exported JSON file
		ext = os.path.splitext(input_filename)[1]
		if ext == '.json':
			shutil.copy(input_filename, map_filename)
		elif ext == '.tmx':
			subprocess.run(['tiled', '--export-map', 'json', input_filename, map_filename], check=True)
		else:
			raise Exception('Unknown Tiled map format "{}" (supported are ".tmx" and ".json"'.format(ext))

		# Read JSON file
		tiled_dict = None
		with open(map_filename, 'r') as json_file:
			tiled_dict = json.load(json_file)

		# Resolve external references
		for tileset_idx in range(len(tiled_dict['tilesets'])):
			tileset = tiled_dict['tilesets'][tileset_idx]
			if 'source' in tileset:
				# Resolve source's absolute path
				source_filename = os.path.normpath(os.path.dirname(map_filename) + '/' + tileset['source'])
				tileset['source'] = source_filename

				# Export sourced file to JSON format to read it
				subprocess.run(['tiled', '--export-tileset', 'json', source_filename, tileset_filename], check=True)

				sourced_tileset = None
				with open(tileset_filename, 'r') as tileset_file:
					sourced_tileset = json.load(tileset_file)

				# Resolve image's absolute path
				if 'image' in sourced_tileset:
					sourced_tileset['image'] = os.path.normpath(os.path.dirname(tileset_filename) + '/' + sourced_tileset['image'])

				# Integrate sourced tileset to the object in our representation
				tileset.update(sourced_tileset)

		return tiled_dict
	finally:
		try:
			unlink(map_filename)
			unlink(tileset_filename)
		except FileNotFoundError:
			pass

def get_layer(tiled_dict, name):
	"""
	Return a layer from its name, or None if not found
	"""
	for layer in tiled_dict['layers']:
		if layer['name'] == name:
			return layer
	return None

def prop(tiled_obj, property_name, default=None):
	"""
	Return a custom property's value
	"""
	return get_property(tiled_obj, property_name, default)

def get_property(tiled_obj, property_name, default=None):
	"""
	Return a custom property's value
	"""
	for prop in tiled_obj.get('properties', []):
		if prop['name'] == property_name:
			if prop['type'] == 'float':
				return float(prop['value'])
			return prop['value']

	return default

def get_class(tiled_obj):
	"""
	Return the class of an object (also known as "type" before Tiled 1.9)
	"""
	class_name = tiled_obj.get('class')
	if class_name is None:
		class_name = tiled_obj.get('type')
	return class_name

def tile_info(gid, tiled_dict):
	"""
	Return information about a tile from its ID in the grid (gid)
	"""
	tile_info = {
		'gid': gid,
		'tileset': None, # index of the tileset this tile belongs
		'index': None, # index of this tile in its tileset
	}

	for tileset_index in range(len(tiled_dict['tilesets'])):
		tileset = tiled_dict['tilesets'][tileset_index]
		if gid >= tileset['firstgid'] and gid < tileset['firstgid'] + tileset['tilecount']:
			tile_info['tileset'] = tileset_index
			tile_info['index'] = gid - tileset['firstgid']
			break

	if tile_info['tileset'] is None:
		raise Exception(f'tile not found for gid={gid}')

	return tile_info
