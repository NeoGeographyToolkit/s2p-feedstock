#!/bin/bash

set -e

export CFLAGS="-I$PREFIX/include -O3 -DNDEBUG -ffast-math -march=native"
export LDFLAGS="-L$PREFIX/lib"

# Fix for missing liblzma.
perl -pi -e "s#(/[^\s]*?lib)/lib([^\s]+).la#-L\$1 -l\$2#g" ${PREFIX}/lib/*.la

make -j${CPU_COUNT}

# Copy this program to the plugins directory
BIN_DIR=${PREFIX}/plugins/stereo/mgm/bin
mkdir -p ${BIN_DIR}
/bin/cp -fv mgm ${BIN_DIR}


