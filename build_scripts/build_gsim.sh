#!/bin/bash

set -e

sudo apt-get update
sudo apt-get install -y flex bison git make libgmp-dev bzip2 time clang-19 lld-19

export CC=clang-19
export CXX=clang++-19


git clone --recursive https://github.com/OpenXiangShan/gsim.git --config submodule.ready-to-run.url=https://github.com/jaypiper/gsim-ready-to-run.git

cd gsim

make build-gsim

make STATIC=1 build-gsim

make init

./build/gsim/gsim --help


printf "To run using any design-core run the command : make run dutName=rocket\n"

