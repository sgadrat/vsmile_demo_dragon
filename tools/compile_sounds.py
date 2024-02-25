#!/usr/bin/env python

import argparse
import os
import subprocess
import tomllib

# Parse command line
parser = argparse.ArgumentParser(description='Compiles a list of sound files.', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('index-file', help='Index file containing the list of sounds')
parser.add_argument('dst-dir', help='Directory to produce compiled result')
args = parser.parse_args()

index_file_path = getattr(args, 'index-file')
dst_dir = getattr(args, 'dst-dir')

project_root = os.path.abspath(os.path.dirname(__file__) + '/..')

# Parse index file
with open(index_file_path, 'rb') as index_file:
	index = tomllib.load(index_file)

assert 'music' in index or 'sound' in index, 'Need at least a music or a sound in the index'
musics = index.get('music', [])
sounds = index.get('sound', [])

for music_index, music in enumerate(musics):
	assert 'name' in music, f'music #{music_index} has no name'

for sound_index, sound in enumerate(sounds):
	assert 'name' in sound, f'sound #{sound_index} has no name'

asset_names = []
for asset in musics + sounds:
	# Checks
	assert asset['name'] not in asset_names, f'name "{asset["name"]}" used multiple times'
	asset_names.append(asset['name'])
	assert 'source' in asset, f'"{asset["name"]}" has no source file (can be any audio file)'
	abs_source = project_root + '/' + asset['source']
	assert os.path.exists(abs_source), f'"{asset["name"]}" source file "{asset["source"]}" not found'
	assert 'format' not in asset or asset['format'] in ['pcm_8', 'pcm_16', 'adpcm'], f'asset "{asset["name"]}" format must pcm8, pcm16 or adpcm'

	# Normalization
	asset['source'] = abs_source
	asset['format'] = asset.get('format', 'u8')

# Compute generated file paths
built_audio_table_filename = os.path.abspath(f'{dst_dir}/audio.built.asm')
relative_audio_table_filename = os.path.relpath(built_audio_table_filename, project_root)

built_assets_filenames = {}
relative_assets_filenames = {}
for asset in musics + sounds:
	built_assets_filenames[asset['name']] = f'{dst_dir}/{asset["name"]}.built.pcm'
	relative_assets_filenames[asset['name']] = os.path.relpath(built_assets_filenames[asset['name']], project_root)

# Convert source files
format_to_ffmpeg = {
	'pcm_8': {'format': 'u8', 'codec': 'pcm_u8'},
	'pcm_16': {'format': 'u16le', 'codec': 'pcm_u16le'},
}
for asset in musics + sounds:
	# Convert source file to the desired format
	assert asset['format'] != 'adpcm', 'TODO implement ADPCM' # sox seams to be able to encode in ADPCM Dialogic/OKI
	cmd = [
		'ffmpeg',
		'-y',
		'-i', asset["source"],
		'-f', format_to_ffmpeg[asset['format']]['format'],
		'-acodec', format_to_ffmpeg[asset['format']]['codec'],
		'-ac', '1',
		'-ar', str(asset['sampling_rate']),
	]
	if 'start' in asset:
		cmd += ['-ss', str(asset['start'])]
	if 'duration' in asset:
		cmd += ['-t', str(asset['duration'])]
	cmd.append(built_assets_filenames[asset['name']])
	subprocess.run(cmd, check=True)

	# Check there is no FFFF sample: not handled by engine... should be, but we want to fail sooner
	with open(built_assets_filenames[asset['name']], 'rb') as asset_file:
		with open(built_assets_filenames[asset['name']] + '.tmp', 'wb') as purged_asset_file:
			if asset['format'] == 'pcm8':
				end_sample = bytes.fromhex('ff')
				patched_sample = bytes.fromhex('fe')
				sample_size = 1
			else:
				end_sample = bytes.fromhex('ffff')
				patched_sample = bytes.fromhex('fffe')
				sample_size = 2

			sample = asset_file.read(sample_size)
			while sample != b'':
				if sample == end_sample:
					print('WARNING: patching sample')
					sample = patched_sample
				purged_asset_file.write(sample)
				sample = asset_file.read(sample_size)
	os.rename(built_assets_filenames[asset['name']] + '.tmp', (built_assets_filenames[asset['name']]))

	# Check file size is even (we don't want to include a binary file with partial word at the end)
	asset_file_stats = os.stat(built_assets_filenames[asset['name']])
	if asset_file_stats.st_size % 2 != 0:
		with open(built_assets_filenames[asset['name']], 'ab') as asset_file:
			asset_file.write(bytes([255]))
	assert os.stat(built_assets_filenames[asset['name']]).st_size % 2 == 0

# Generate asm file linking all that
format_index = {'pcm_8': 0, 'pcm_16': 1, 'adpcm': 2}
with open(built_audio_table_filename, 'wt') as asm_file:
	# Data and info for each asset
	for asset in musics + sounds:
		# Asset's label
		asm_file.write(f'audio_asset_{asset["name"]}:\n')

		# Asset's info
		phase = int(asset["sampling_rate"] * (2**19 / 281250))
		zero_point = 0x0080 if asset["format"] == 'pcm_8' else 0x8000
		# Channel control
		# ff_tt_llllll_ssssss
		#  u: unused
		#  f: sample format (0=8-bit, 1=16-bit, 2=adpcm, 3=???)
		#  t: Tone Mode (0=software PCM, 1=one shot PCM, 2=Manual loop PCM, 3=???)
		#  l: Loop address segment
		#  s: Sample address segment
		channel_control = (
			(format_index[asset["format"]] << 14) +
			((1 if asset in sounds else 2) << 12)
		)
		asm_file.write(f'\t.dw 0x{phase >> 16:04x} ; Phase msw\n')
		asm_file.write(f'\t.dw 0x{phase & 0xffff:04x} ; Phase lsw\n')
		asm_file.write(f'\t.dw (audio_asset_{asset["name"]}+6) & 0xffff ; Start lsw\n')
		asm_file.write(f'\t.dw (audio_asset_{asset["name"]}+6) & 0xffff ; Loop lsw\n')
		asm_file.write(f'\t.dw {bin(channel_control)} + (((audio_asset_{asset["name"]}+6) >> 16) << 6) + ((audio_asset_{asset["name"]}+6) >> 16) ; Channel control ff_tt_llllll_ssssss\n')
		asm_file.write(f'\t.dw {hex(zero_point)} ; Wave zero point\n')

		# Asset's data
		asm_file.write(f'\t.binfile "{relative_assets_filenames[asset["name"]]}"\n')
		asm_file.write(f'\t.dw 0xffff ; A byte at "ff" means sample end for the SPU (need a word at "ffff" if pcm16, so a word always works)\n')
		asm_file.write('\n')

	# Musics index table
	asm_file.write('audio_musics:\n')
	for asset in musics:
		asm_file.write(f'.dw audio_asset_{asset["name"]} & 0xffff, audio_asset_{asset["name"]} >> 16\n')
	asm_file.write('\n')

	# Sounds index table
	asm_file.write('audio_sounds:\n')
	for asset in sounds:
		asm_file.write(f'.dw audio_asset_{asset["name"]} & 0xffff, audio_asset_{asset["name"]} >> 16\n')
	asm_file.write('\n')
