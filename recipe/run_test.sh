#!/bin/bash

set -e

ls
cd test
ln -s ${GXX} g++
# cp ../xcrun .
# cp ../xcodebuild .
export PATH=${PWD}:${PATH}
if [[ -f hello-minimal.pro ]]; then
  qmake hello-minimal.pro
else
  qmake hello.pro
fi
make
./hello
# Only test that this builds
make clean
# qmake qtwebengine.pro
# make
