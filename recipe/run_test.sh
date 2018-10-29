#!/bin/bash

cd test
ln -s ${GXX} g++
if [[ $(uname) == Darwin ]]; then
  export PATH=${PREFIX}/xc-avoidance/bin
  export CONDA_BUILD_SYSROOT=/opt/MacOSX10.9.sdk
fi
export PATH=${PWD}:${PATH}
qmake hello.pro
make
./hello
