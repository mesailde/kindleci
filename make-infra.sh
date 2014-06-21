#!/bin/bash
. config.env

export MAKEFLAGS
export PATH=$PATH:$CROSS_PATH

mkdir -p downloads work build
BUILD_DIR="$(readlink -f build)"

fetch() {
	local destfile=downloads/"$1"
	while [[ ! -f "$destfile" || `md5sum "$destfile"|cut -d\  -f1` != "$2" ]]; do
		rm "$destfile" 2>/dev/null
		wget -O "$destfile" "$3" || return $?
	done
}

move_up_mountpoint() {
	pushd $BUILD_DIR
	local dir="./$DEV_MOUNTPOINT"
	mv "$dir"/* .
	while [[ ! -z "$dir" && "$dir" != "." ]]; do
		rmdir "$dir"
		dir="$(dirname "$dir")"
	done
	popd
}

build_valgrind() {
	[[ -f work/.done.valgrind ]] && return 0
	local ver=3.9.0
	fetch valgrind-${ver}.tar.bz2 0947de8112f946b9ce64764af7be6df2 http://valgrind.org/downloads/valgrind-${ver}.tar.bz2
	rm -rf work/valgrind-${ver} 2>/dev/null
	tar -C work -jxf downloads/valgrind-${ver}.tar.bz2 || return $?
	pushd work/valgrind-${ver}
	CC=${CROSS_PREFIX}-gcc \
	CPP=${CROSS_PREFIX}-cpp \
	CXX=${CROSS_PREFIX}-g++ \
	LD=${CROSS_PREFIX}-ld \
	AR=${CROSS_PREFIX}-ar \
	./configure --target=$CROSS_PREFIX \
		--host=$(echo $CROSS_PREFIX | sed s,arm-,armv7-,) \
		--prefix="$DEV_MOUNTPOINT/valgrind" || return $?
	make || return $?
	make install DESTDIR="$BUILD_DIR" || return $?
	popd
	move_up_mountpoint
	touch work/.done.valgrind
}

install_libc6_dbg() {
	[[ -f work/.done.libc6dbg ]] && return 0
	local ver=2.12.1-0ubuntu6
	fetch libc6-dbg_${ver}_armel.deb aa6bb85226e6154ea6b30c1a3b8f9adc http://launchpadlibrarian.net/55372239/libc6-dbg_${ver}_armel.deb
	mkdir -p work/libc6dbg
	pushd work/libc6dbg
	ar x ../../downloads/libc6-dbg_${ver}_armel.deb || return $?
	tar -zxf data.tar.gz || return $?
	cp -r usr/lib/debug "$BUILD_DIR/valgrind" || return $?
	popd
	touch work/.done.libc6dbg
}

build_luajit() {
	[[ -f work/.done.luajit ]] && return 0
	local ljdir="luajit-2.0"
	pushd downloads
	if [[ ! -d "$ljdir" ]]; then
		git clone http://luajit.org/git/luajit-2.0.git "$ljdir" || return $?
		cd "$ljdir"
	else
		cd "$ljdir"
		git pull
	fi
	git checkout v2.1 || return $?
	rm -rf "../../work/$ljdir" 2>/dev/null
	git clone . "../../work/$ljdir" || return $?
	popd
	pushd "work/$ljdir"
	make HOST_CC="gcc -m32" CROSS="${CROSS_PREFIX}-" \
		TARGET_CFLAGS="-march=armv7-a -mtune=cortex-a8 -mfpu=neon -marm" \
		PREFIX="$DEV_MOUNTPOINT/luajit" \
		amalg || return $?
	make install PREFIX="$DEV_MOUNTPOINT/luajit" DESTDIR="$BUILD_DIR" || return $?
	cp src/lj.supp "$BUILD_DIR/valgrind/lib/valgrind"
	popd
	move_up_mountpoint
	touch work/.done.luajit
}

build_busted() {
	[[ -f work/.done.busted ]] && return 0
	LUAROCKS_CONFIG="work/luarocks_conf.lua"
	cat > "$LUAROCKS_CONFIG" << EOF
rocks_trees = {
	[[$BUILD_DIR/luajit]]
}
variables = {
	CC = [[${CROSS_PREFIX}-gcc]],
	CPP = [[${CROSS_PREFIX}-cpp]],
	CXX = [[${CROSS_PREFIX}-g++]],
	LD = [[${CROSS_PREFIX}-gcc]],
	AR = [[${CROSS_PREFIX}-ar]],
	LUA_INCDIR = [[${BUILD_DIR}/luajit/include/luajit-2.1]],
	LUA_LIBDIR = [[${BUILD_DIR}/luajit/lib]],
	LUA_BINDIR = [[${BUILD_DIR}/luajit/bin]],
	LUAROCKS_UNAME_M= [[armv7l]],
	CFLAGS = [[-march=armv7-a -mtune=cortex-a8 -mfpu=neon -marm -shared -fPIC]]
}
EOF
	export LUAROCKS_CONFIG
	luarocks install busted || return $?
	touch work/.done.busted
}

build_valgrind || exit $?
install_libc6_dbg || exit $?
build_luajit || exit $?
build_busted || exit $?
