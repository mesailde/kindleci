#!/bin/bash
set -xe
./update-koreader.sh "$1"
./make-koreader.sh debug 
./run-tests.sh
