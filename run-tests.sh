#!/bin/bash
. config.env

# Run compatibility quirks if they exist
if [[ -x ./quirks.sh ]]; then ./quirks.sh || exit $?; fi

USE_VALGRIND=0
if [[ $# > 0 ]]; then
	if [[ $1 == "--use-valgrind" ]]; then
		USE_VALGRIND=1
		shift
		VALGRIND_ARGS="$@"
	else
		echo "usage: $0 [--use-valgrind [valgrind_args]]"
		exit 1
	fi
fi

VALGRIND_CMD=""
if [[ $USE_VALGRIND == 1 ]]; then
	VALGRIND_CMD="$DEV_MOUNTPOINT/valgrind/bin/valgrind $VALGRIND_ARGS \
--extra-debuginfo-path=$DEV_MOUNTPOINT/valgrind/debug \
--suppressions=$DEV_MOUNTPOINT/valgrind/lib/valgrind/lj.supp "
fi

BUSTED_SCRIPT="$DEV_MOUNTPOINT/luajit/bin/busted_bootstrap"

cat > build/run-tests.sh << EOF
#!/bin/sh
export LUA_PATH='./?.lua;$DEV_MOUNTPOINT/luajit/share/lua/5.1/?.lua;$DEV_MOUNTPOINT/luajit/share/lua/5.1/?/init.lua'
export LUA_CPATH='./?.so;$DEV_MOUNTPOINT/luajit/lib/lua/5.1/?.so;$DEV_MOUNTPOINT/luajit/lib/lua/5.1/loadall.so'
export TESSDATA_PREFIX="$DEV_MOUNTPOINT/koreader/data"
cd "$DEV_MOUNTPOINT/koreader"
set -xe
${VALGRIND_CMD}./luajit $BUSTED_SCRIPT spec/base/unit
${VALGRIND_CMD}./luajit $BUSTED_SCRIPT spec/front/unit 
EOF
chmod +x build/run-tests.sh

if ! ssh kindle [ -x "$DEV_MOUNTPOINT/run-tests.sh" ]; then
	BUILD_PATH="$(readlink -f build)"
	ssh kindle mkdir -p "$DEV_MOUNTPOINT" || exit $?
	ssh kindle sshfs "master:$BUILD_PATH" "$DEV_MOUNTPOINT" || exit $?
fi

# Needed for zeromq tests
ssh kindle /usr/sbin/iptables -A INPUT -i lo -j ACCEPT

ssh kindle "$DEV_MOUNTPOINT/run-tests.sh"
STATUS=$?

ssh kindle /usr/sbin/iptables -D INPUT -i lo -j ACCEPT

exit $STATUS
