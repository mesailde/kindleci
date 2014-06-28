#!/bin/bash
set -xe
./update-koreader.sh "$1"
./make-koreader.sh release
./run-tests.sh
