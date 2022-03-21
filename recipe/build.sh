set -exou
rm -rf qt-build
mkdir -p qt-build
pushd qt-build

if [[ $(uname) == "Darwin" ]]; then
  export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
  export AR=$(basename ${AR})
  export RANLIB=$(basename ${RANLIB})
  export STRIP=$(basename ${STRIP})
  export OBJDUMP=$(basename ${OBJDUMP})
  export CC=$(basename ${CC})
  export CXX=$(basename ${CXX})
  echo "switch to qtwebengine/src/3rdparty ..."
  pushd ../qtwebengine/src/3rdparty
  git checkout -f 90-based
  popd
  echo "restore to $SRC_DIR ..."
  # Let Qt set its own flags and vars
  for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
  do
      echo $x # unset $x
  done

  NPROC=$CPU_COUNT

  PLATFORM=""
  if [[ $(arch) == "arm64" ]]; then
    PLATFORM="-device-option QMAKE_APPLE_DEVICE_ARCHS=arm64"
  fi
  echo "setting up before configure ..."
  export CXXFLAGS="${CXXFLAGS} -Wno-non-c-typedef-for-linkage"
 
  # Avoid Xcode
    #cp "${RECIPE_DIR}"/xcrun .
    #cp "${RECIPE_DIR}"/xcodebuild .
    # Some test runs 'clang -v', but I do not want to add it as a requirement just for that.
    #ln -s "${CXX}" ${HOST}-clang || true
    # For ltcg we cannot use libtool (or at least not the macOS 10.9 system one) due to lack of LLVM bitcode support.
    #ln -s "${LIBTOOL}" libtool || true
    # Just in-case our strip is better than the system one.
    #ln -s "${STRIP}" strip || true
    #chmod +x ${HOST}-clang libtool strip
    # Qt passes clang flags to LD (e.g. -stdlib=c++)
    #export LD=${CXX}
    #PATH=${PWD}:${PATH}

if [[ $target_platform == osx-arm64 ]]; then
    list_config_to_patch=$(find . -name config.guess | sed -E 's/config.guess//')
    for config_folder in $list_config_to_patch; do
        echo "copying config to $config_folder ...\n"
        cp -v $BUILD_PREFIX/share/libtool/build-aux/config.* $config_folder
    done

    cp -r ${RECIPE_DIR}/chrome_cfg/Chromium/arm64 ${SRC_DIR}/qtwebengine/src/3rdparty/chromium/third_party/ffmpeg/chromium/config/Chromium/mac/.
    cp -r ${RECIPE_DIR}/chrome_cfg/Chrome/arm64 ${SRC_DIR}/qtwebengine/src/3rdparty/chromium/third_party/ffmpeg/chromium/config/Chrome/mac/.

fi

#export QMAKE_MAC_SDK=${CONDA_BUILD_SYSROOT}
export QMAKE_MACOSX_DEPLOYMENT_TARGET=11.1
export QMAKE_PKG_CONFIG=${PREFIX}/lib/pkgconfig
export PKG_CONFIG=${PREFIX}/lib/pkgconfig
export PKG_CONFIG=${PREFIX}/lib/pkgconfig
export PKG_CONFIG_LIBDIR=$(${PREFIX}/bin/pkg-config --pclibdir)

  ../configure -prefix ${PREFIX} \
             -libdir ${PREFIX}/lib \
             -bindir ${PREFIX}/bin \
             -headerdir ${PREFIX}/include/qt \
             -archdatadir ${PREFIX} \
             -datadir ${PREFIX} \
             $PLATFORM \
             -I ${PREFIX}/include \
             -L ${PREFIX}/lib \
             -R $PREFIX/lib \
             -opensource \
             -nomake examples \
             -nomake tests \
	     -confirm-license \
             -system-libjpeg \
             -system-libpng \
             -system-zlib \
             -optimize-size \
             -release \
             -no-framework
             # -sdk macosx10.14

fi

# 7/23/2021 PJY: Specifying the CPATH and LD_LIBRARY_PATH seem to be important for
# finding additional headers and libs (e.g. event.h).
CPATH=$PREFIX/include LD_LIBRARY_PATH=$PREFIX/lib make -j${CPU_COUNT} || exit 1

make install

# Remove XCB headers
rm -rf $PREFIX/include/xcb
