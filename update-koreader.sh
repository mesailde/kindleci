#!/bin/bash
# Fetch or update koreader
pushd downloads
if [[ ! -d koreader ]]; then
	git clone https://github.com/koreader/koreader.git
	cd koreader
else
	cd koreader
	git pull
fi
make fetchthirdparty
popd
