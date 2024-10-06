#!/bin/bash

STACK_SIZE=1048576
HEAP_SIZE=67108864

emsdk activate latest

if [ ! -d "build" ]; then
  mkdir build
fi

pushd build

odin build ../src -target=freestanding_wasm32 -out:odin -build-mode:obj -debug -show-system-calls
emcc -o index.html ../src/main.c odin.wasm.o ../lib/libraylib.a -s USE_GLFW=3 -DWEB_BUILD -s TOTAL_MEMORY=$HEAP_SIZE -sERROR_ON_UNDEFINED_SYMBOLS=0 -sASYNCIFY

popd
