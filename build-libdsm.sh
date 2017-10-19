#!/bin/bash

# global build settings
export SDKPATH=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
export SIMSDKPATH=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
export MIN_IOS_VERSION=7.0
export HOST=arm-apple-darwin
export LDFLAGS_NATIVE="-isysroot $SDKPATH"
export LDFLAGS_SIMULATOR="-isysroot $SIMSDKPATH"
export TASN1_CFLAGS="-Ilibtasn1/include"
export TASN1_LIBS="-Llibtasn1 -ltasn1"
export ARCHES=( armv7 armv7s arm64 i386 x86_64 )

# libtasn1 defines
export TASN1_URL="https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.12.tar.gz"
export TASN1_DIR_NAME="libtasn1-4.12"

# libdsm defines
export DSM_URL="https://github.com/videolabs/libdsm/releases/download/v0.2.8/libdsm-0.2.8.tar.gz"
export DSM_DIR_NAME="libdsm-0.2.8"

######################################################################

mkdir build
cd build

echo "Checking libtasn1..."

# download the latest libtasn1 library
if [ ! -d $TASN1_DIR_NAME ]; then
  echo "Downloading libtasn1..."
  curl -o $TASN1_DIR_NAME.tar.gz $TASN1_URL
  gunzip -c $TASN1_DIR_NAME.tar.gz | tar xopf -
fi
echo "... Done"

echo "Checking libdsm..."

# download the latest version of libdsm
if [ ! -d $DSM_DIR_NAME ]; then
  echo "Downloading libdsm..."
  curl -L -J -O $DSM_URL
  gunzip -c $DSM_DIR_NAME.tar.gz | tar xopf -
fi

echo "...Done"

### build tasn1 ###

### remove the previous build of libtasn1 from libdsm
rm -rf $DSM_DIR_NAME/libtasn1

cd $TASN1_DIR_NAME
rm -rf build

# build libtasn1 for each architecture
build_files=""
for i in "${ARCHES[@]}"
do
  build_files="$build_files build/$i/lib/libtasn1.a"
  export ARCH=$i
  if [[ $i == *"arm"* ]]
  then
    export LDFLAGS=$LDFLAGS_NATIVE
  else
    export LDFLAGS=$LDFLAGS_SIMULATOR
  fi
  export CFLAGS="-arch $ARCH $LDFLAGS -miphoneos-version-min=$MIN_IOS_VERSION -fembed-bitcode -Wno-sign-compare"
  ./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install
  make clean
done

# merge the compiled binaries into a single universal one
mkdir -p build/universal
lipo -create $build_files -output build/universal/libtasn1.a

echo "Copying Headers Across"

# copy headers across
mkdir build/universal/include
cp -R build/armv7/include build/universal/

cd ../

# copy binary to libdsm folder for its build process
cp -R $TASN1_DIR_NAME/build/universal $DSM_DIR_NAME/libtasn1

### build libdsm ###

cd $DSM_DIR_NAME
rm -rf build

## stupid hack: something in the build process is removing this file
cp contrib/spnego/spnego_asn1.c contrib/spnego/spnego_asn1.c.orig
build_files=""
for i in "${ARCHES[@]}"
do
  build_files="$build_files build/$i/lib/libdsm.a"
  export ARCH=$i
  if [[ $i == *"arm"* ]]
  then
    export LDFLAGS=$LDFLAGS_NATIVE
  else
    export LDFLAGS=$LDFLAGS_SIMULATOR
  fi
  export CFLAGS="-arch $ARCH $LDFLAGS -miphoneos-version-min=$MIN_IOS_VERSION -fembed-bitcode -DNDEBUG -Wno-sign-compare"
  ./configure --host=$HOST --prefix=$PWD/build/$ARCH && make && make install
  make clean
  cp contrib/spnego/spnego_asn1.c.orig contrib/spnego/spnego_asn1.c
done

# merge the compiled binaries into a single universal one
mkdir -p build/universal
lipo -create $build_files -output build/universal/libdsm.a

# copy headers across
mkdir build/universal/include
cp -R build/armv7/include build/universal

# remove leading `bdsm/` from include paths
sed -i '' -e 's/\"bdsm\//\"/g' build/universal/include/bdsm/*.h
sed -i '' -e 's/<libtasn1.h>/\"libtasn1.h\"/g' build/universal/include/bdsm/*.h

# move final product to parent directory
cp -R build/universal/* ../../libdsm/
cp libtasn1/libtasn1.a ../../libdsm/
cp libtasn1/include/libtasn1.h ../../libdsm/include/bdsm/
