#!/bin/bash

deps_dir=$(readlink -f "$(dirname "$0")")/deps
selected_step="$1"

step_make_deps_dir() {
	mkdir -p "$deps_dir"
}

step_get_git() {
	#TODO
	echo "get git"
}

step_get_python() {
	brew install python
}

step_get_naken_asm() {
	cd "$deps_dir"
	git clone https://github.com/mikeakohn/naken_asm.git
	cd naken_asm
	./configure
	make
}

step_get_tiled() {
	brew install tiled
}

total_steps=0
failed_steps=0
step() {
	if [ ! -z "$selected_step" -a "$selected_step" != "$1" ]; then
		return
	fi

	echo
	echo "========================================================="
	echo "  STEP $1"
	echo "========================================================="
	echo

	total_steps=$((total_steps + 1))

	cmd="step_$1"
	$cmd
	if [ $? -ne 0 ]; then
		failed_steps=$((failed_steps + 1))
		echo "FAIL: $1"
		return 1
	else
		echo "SUCCESS: $1"
	fi
}

step make_deps_dir
step get_git
step get_python
step get_naken_asm
step get_tiled

if [ "$failed_steps" -ne 0 ]; then
	echo "$failed_steps failed steps"
else
	echo
	echo "Depencies ready in $deps_dir"
	echo
	echo "build:"
	echo "NAKEN_BIN='$deps_dir/naken_asm/naken_asm' ./build.sh"
fi
