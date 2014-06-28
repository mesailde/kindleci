#!/bin/bash
# Fetch or update koreader
set -e
pushd downloads
if [[ ! -d koreader ]]; then
	git clone https://github.com/koreader/koreader.git
	cd koreader
else
	cd koreader
	git checkout -f master
	git pull
fi
if [[ ! -z "$1" ]]; then
	git checkout -f "$1"
fi
make fetchthirdparty
popd
