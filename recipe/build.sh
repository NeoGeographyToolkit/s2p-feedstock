#!/bin/bash

set -e

export CFLAGS="-I$PREFIX/include -O3 -DNDEBUG -march=native"
export LDFLAGS="-L$PREFIX/lib"

# Fix for missing liblzma
perl -pi -e "s#(/[^\s]*?lib)/lib([^\s]+).la#-L\$1 -l\$2#g" ${PREFIX}/lib/*.la

baseDir=$(pwd)

extraFlag=""
if [ "$(uname)" = "Darwin" ]; then
    EXT='.dylib'
    extraFlag="-DCMAKE_SHARED_LINKER_FLAGS=-headerpad_max_install_names"
    export LDFLAGS="$LDFLAGS -headerpad_max_install_names"
else
    EXT='.so'
fi

# Build the desired programs

echo Building MGM
cd 3rdparty/mgm
echo Work dir: $(pwd)
perl -pi -e "s#CFLAGS=#CFLAGS=$CFLAGS #g" Makefile
perl -pi -e "s#LDFLAGS=#LDFLAGS='$LDFLAGS' #g" Makefile 
make -j${CPU_COUNT}
cd $baseDir

echo Building mgm_multi
cd 3rdparty/mgm_multi
echo Work dir: $(pwd)
# Fix for arm64/mac, where long double and double have the same size, so the
# float-size switch in iio.c ends up with a duplicate case and fails to compile.
# Add an explicit if before the switch and comment out the now-duplicate case.
perl -pi -e 's{(if \(signed_sample\) fail\("signed floats are a no-no!"\);)}{$1\n\t\tif (sample_size == sizeof(double)) return IIO_TYPE_DOUBLE;}g' iio/iio.c
perl -pi -e 's{^(\s*)case sizeof\(double\):(\s*)return IIO_TYPE_DOUBLE;}{$1//case sizeof(double):$2return IIO_TYPE_DOUBLE;}g' iio/iio.c
# The Makefile CFLAGS is ?=, so the exported CFLAGS/LDFLAGS above are used. The
# iio include and libs (fftw, png, tiff, jpeg) come from the Makefile and PREFIX.
make -j${CPU_COUNT} mgm_multi
cd $baseDir

echo Building msmw
cd 3rdparty/msmw
echo Work dir: $(pwd)
mkdir -p build
cd build
cmake .. -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CFLAGS" \
    -DPNG_LIBRARY_RELEASE="${PREFIX}/lib/libpng${EXT}"     \
    -DTIFF_LIBRARY_RELEASE="${PREFIX}/lib/libtiff${EXT}"   \
    -DZLIB_LIBRARY_RELEASE="${PREFIX}/lib/libz${EXT}"      \
    -DJPEG_LIBRARY="${PREFIX}/lib/libjpeg${EXT}" $extraFlag
make -j${CPU_COUNT}
cd $baseDir

echo Building msmw2
cd 3rdparty/msmw2
echo Work dir: $(pwd)
mkdir -p build
cd build
cmake ..                                                   \
    -DCMAKE_C_FLAGS="$CFLAGS" -DCMAKE_CXX_FLAGS="$CFLAGS"  \
    -DPNG_LIBRARY_RELEASE="${PREFIX}/lib/libpng${EXT}"     \
    -DTIFF_LIBRARY_RELEASE="${PREFIX}/lib/libtiff${EXT}"   \
    -DZLIB_LIBRARY_RELEASE="${PREFIX}/lib/libz${EXT}"      \
    -DJPEG_LIBRARY="${PREFIX}/lib/libjpeg${EXT}" $extraFlag
make -j${CPU_COUNT}
cd $baseDir

# Install the desired programs

BIN_DIR=${PREFIX}/plugins/stereo/mgm/bin
mkdir -p ${BIN_DIR}
/bin/cp -fv 3rdparty/mgm/mgm ${BIN_DIR}

BIN_DIR=${PREFIX}/plugins/stereo/mgm_multi/bin
mkdir -p ${BIN_DIR}
/bin/cp -fv 3rdparty/mgm_multi/mgm_multi ${BIN_DIR}

BIN_DIR=${PREFIX}/plugins/stereo/msmw/bin
mkdir -p ${BIN_DIR}
/bin/cp -fv \
    3rdparty/msmw/build/libstereo/iip_stereo_correlation_multi_win2 \
    ${BIN_DIR}/msmw

BIN_DIR=${PREFIX}/plugins/stereo/msmw2/bin
mkdir -p ${BIN_DIR}
/bin/cp -fv \
    3rdparty/msmw2/build/libstereo_newversion/iip_stereo_correlation_multi_win2_newversion \
    ${BIN_DIR}/msmw2

