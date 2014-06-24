#!/bin/bash
. config.env

export PATH=$PATH:$CROSS_PATH

BUILD_DIR="$(readlink -f build)"
ARM_ARCH="-march=armv7-a -mtune=cortex-a8 -mfpu=neon -mfloat-abi=softfp -mthumb"

if [[ "$1" == "debug" ]]; then
	STRIP="echo"           # do not strip executables
	CCDEBUG="-O0 -g"       # for LuaJIT
	BASE_CFLAGS="-O2 -g"   # for everything else
	# Extra CFLAGS for LuaJIT
	XCFLAGS="-DLUAJIT_USE_GDBJIT -DLUA_USE_APICHECK -DLUA_USE_ASSERT"
	XCFLAGS="-DLUAJIT_USE_VALGRIND -DLUAJIT_USE_SYSMALLOC"
	XCFLAGS="$XCFLAGS -I${BUILD_DIR}/valgrind/include"
elif [[ "$1" == "release" ]]; then
	STRIP="${CROSS_PREFIX}-strip"
	BASE_CFLAGS="-O2 -fomit-frame-pointer -frename-registers -fweb -pipe"
	CCDEBUG=""
	XCFLAGS=""
else
	echo "usage: $0 debug|release"
	exit 1
fi

rm -rf work/koreader 2>/dev/null
cp -r downloads/koreader work

pushd work/koreader
unset MAKEFLAGS
make TARGET=kindle CHOST="${CROSS_PREFIX}" \
	BASE_CFLAGS="${BASE_CFLAGS}" \
	ARM_BACKWARD_COMPAT_CFLAGS="" \
	ARM_BACKWARD_COMPAT_CXXFLAGS="" \
	ARM_ARCH="${ARM_ARCH}" \
	STRIP="${STRIP}" \
	CCDEBUG="${CCDEBUG}" XCFLAGS="${XCFLAGS}" \
	kindleupdate || exit $?
popd

rm -rf build/koreader
pushd build
unzip ../work/koreader/koreader-*.zip 'koreader/*' || exit $?
cd koreader

# Copy toolchain's libstdc++
find "$CROSS_PATH/.." -name libstdc++.so.6 -exec cp '{}' libs \;

# Copy tests
mkdir -p spec/front
cp -r ../../work/koreader/spec/unit spec/front
cp -r ../../work/koreader/test spec/front/data
ln -sf ../data spec/front/unit/data  # link otherwise busted crashes
mkdir -p spec/base
cp -r ../../work/koreader/koreader-base/spec/unit spec/base
mv spec/base/unit/data spec/base
ln -sf ../data spec/base/unit/data   # link otherwise busted crashes
popd

fetch() {
	local destfile=downloads/"$1"
	while [[ ! -f "$destfile" || `md5sum "$destfile"|cut -d\  -f1` != "$2" ]]; do
		rm "$destfile" 2>/dev/null
		wget -O "$destfile" "$3" || return $?
	done
}

# Extract Tesseract English data
# (needed for spec/base/unit tests)
tessver=3.01
fetch tesseract-ocr-${tessver}.eng.tar.gz 89c139a73e0e7b1225809fc7b226b6c9 https://tesseract-ocr.googlecode.com/files/tesseract-ocr-${tessver}.eng.tar.gz
tar --strip-components=1 -zxvf downloads/tesseract-ocr-${tessver}.eng.tar.gz -C build/koreader/data
