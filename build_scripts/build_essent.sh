#!/bin/bash

set -e

sudo apt update
sudo apt install -y build-essential cmake git \
    libtbb-dev zlib1g-dev python3 python3-pip \
    libboost-all-dev \
    openjdk-17-jdk \
    git \
    build-essential \
    cmake \
    g++ \
    libtbb-dev \
    wget \
    curl \
    unzip \
    pkg-config \
    curl \
    unzip \
    zip

# === Install sbt via SDKMAN ===
if [ ! -d "$HOME/.sdkman" ]; then
  curl -s "https://get.sdkman.io" | bash
fi
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install sbt || true

# === Clone KaHyPar ===
git clone https://github.com/kahypar/kahypar.git
cd kahypar
git submodule update --init --recursive

mkdir build && cd build

cmake .. -DCMAKE_BUILD_TYPE=Release -DKAHYPAR_BUILD_TESTS=OFF -DKAHYPAR_USE_PYTHON=OFF

make -j$(nproc)

sudo make install

sudo ldconfig

sudo cp kahypar/application/KaHyPar /usr/local/bin/kahypar

sudo ln -s /kahypar/application/KaHyPar /usr/local/bin/KaHyPar

export PATH=kahypar/application:$PATH

kahypar --help
printf "Kahypar installed Successfully =)"

cd ../..

# === Clone Essent ===
if [ ! -d "$ES_DIR" ]; then
    echo "[INFO] Cloning Essent..."
    git clone -b repcut https://github.com/ucsc-vama/essent.git
fi
# ======

cd essent
sbt assembly

printf "To run essent use the command: java -jar utils/bin/essent.jar -O0 --parallel <partitions> fir_path"
