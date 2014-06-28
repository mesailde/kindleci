#!/bin/bash
# Fetch or update koreader
pushd downloads
if [[ ! -d koreader ]]; then
	git clone https://github.com/koreader/koreader.git || exit $?
	cd koreader
else
	cd koreader
	git pull || exit $?
fi
if [[ ! -z "$1" ]]; then
	git checkout "$1" || exit $?
fi
make fetchthirdparty || exit $?
popd
