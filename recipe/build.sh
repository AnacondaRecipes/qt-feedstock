#!/bin/bash

# Compile
# -------
chmod +x configure

# Let Qt set its own flags and vars
for x in OSX_ARCH CFLAGS CXXFLAGS LDFLAGS
do
    unset $x
done

MAKE_JOBS=$CPU_COUNT

if [[ -d qtwebkit ]]; then
  # From: http://www.linuxfromscratch.org/blfs/view/svn/x/qtwebkit5.html
  # Should really be a patch:
  sed -i.bak -e '/CONFIG/a QMAKE_CXXFLAGS += -Wno-expansion-to-defined' qtwebkit/Tools/qmake/mkspecs/features/unix/default_pre.prf
fi

if [[ ${HOST} =~ .*linux.* ]]; then

    # Force static linking to OpenSSL
    find ${PREFIX}/lib -name "libcrypto.so*" -exec rm -rf {} \;
    find ${PREFIX}/lib -name "libssl.so*" -exec rm -rf {} \;
    export OPENSSL_LIBS="-L${PREFIX}/lib -lssl -lcrypto -ldl"

    # Prevent:
    # /opt/conda/conda-bld/qt_1535122084180/_h_env_..placehold_/bin/../lib/gcc/i686-conda_cos6-linux-gnu/7.3.0/../../../../i686-conda_cos6-linux-gnu/bin/ld:
    # warning: libz.so.1, needed by /opt/conda/conda-bld/qt_1535122084180/work/qtbase/lib/libQt5Core.so, not found (try using -rpath or -rpath-link)
    # ..
    echo "QMAKE_LFLAGS            += -Wl,-rpath-link,${PREFIX}/lib" >> qtbase/mkspecs/linux-g++/qmake.conf

    if ! which ruby > /dev/null 2>&1; then
        echo "You need ruby to build qtwebkit"
        exit 1
    fi

    ln -s ${GXX} g++ || true
    ln -s ${GCC} gcc || true
    export PATH=${PWD}:${PATH}
    export LD=${GXX}
    export CC=${GCC}
    export CXX=${GXX}

    # Qt has some braindamaged behaviour around handling compiler system include and lib paths. Basically, if it finds any include dir
    # that is a system include dir then it prefixes it with -isystem. Problem is, passing -isystem <blah> causes GCC to forget all the
    # other system include paths. The reason that Qt needs to know about these paths is probably due to moc needing to know about them
    # so we cannot just elide them altogether. Instead, as soon as Qt sees one system path it needs to add them all as a group, in the
    # correct order. This is probably fairly tricky so we work around needing to do that by having them all be present all the time.
    #
    # Futher, any system dirs that appear from the output from pkg-config (QT_XCB_CFLAGS) can cause incorrect emission ordering so we
    # must filter those out too which we do with a pkg-config wrapper.
    #
    # References:
    #
    # https://github.com/voidlinux/void-packages/issues/5254
    # https://github.com/qt/qtbase/commit/0b144bc76a368ecc6c5c1121a1b51e888a0621ac
    # https://codereview.qt-project.org/#/c/157817/
    #
    declare -a INCDIRS
    INCDIRS=(-I ${PREFIX}/include)
    SYSINCDIRS=$(echo "" | ${CXX} -xc++ -E -v - 2>&1 | awk '/#include <...> search starts here:/{flag=1;next}/End of search list./{flag=0}flag')
    for SYSINCDIR in ${SYSINCDIRS}; do
      INCDIRS+=(-I ${SYSINCDIR})
    done
    echo "#!/usr/bin/env sh"                                                                    > ./pkg-config
    echo "pc_res=\$(CONDA_PREFIX=\${CONDA_PREFIX_1} \${BUILD_PREFIX}/bin/pkg-config \"\$@\")"  >> ./pkg-config
    echo "res=\$?"                                                                             >> ./pkg-config
    echo "if [[ \${res} != 0 ]]; then"                                                         >> ./pkg-config
    echo "  echo \${pc_res}"                                                                   >> ./pkg-config
    echo "  exit \${res}"                                                                      >> ./pkg-config
    echo "fi"                                                                                  >> ./pkg-config
    echo "echo \${pc_res} | sed 's/[a-zA-Z0-9_-/\.]*sysroot[a-zA-Z0-9_-/\.]*//g'"              >> ./pkg-config
    echo "exit 0"                                                                              >> ./pkg-config
    chmod +x ./pkg-config
    export PATH=${PWD}:${PATH}

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -R $PREFIX/lib \
                "${INCDIRS[@]}" \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip enginio \
                -skip location \
                -skip sensors \
                -skip serialport \
                -skip serialbus \
                -skip quickcontrols2 \
                -skip wayland \
                -skip canvas3d \
                -skip 3d \
                -skip webengine \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -system-sqlite \
                -plugin-sql-sqlite \
                -qt-pcre \
                -qt-xcb \
                -qt-xkbcommon \
                -xkb-config-root $PREFIX/lib \
                -dbus \
                -no-linuxfb \
                -no-libudev \
                -no-avx \
                -no-avx2 \
                -cups \
                -openssl-linked \
                -no-use-gold-linker \
                -Wno-expansion-to-defined \
                -D _X_INLINE=inline \
                -D XK_dead_currency=0xfe6f \
                -D _FORTIFY_SOURCE=2 \
                -D XK_ISO_Level5_Lock=0xfe13 \
                -D FC_WEIGHT_EXTRABLACK=215 \
                -D FC_WEIGHT_ULTRABLACK=FC_WEIGHT_EXTRABLACK \
                -D GLX_GLXEXT_PROTOTYPES
# To get a much quicker turnaround you can add this: (remember also to add the backslash after GLX_GLXEXT_PROTOTYPES)
# -skip qtwebsockets -skip qtwebchannel -skip qtwayland -skip qtsvg -skip qtsensors -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools

# If we must not remove strict_c++ from qtbase/mkspecs/features/qt_common.prf
# (0007-qtbase-CentOS5-Do-not-use-strict_c++.patch) then we need to add these
# defines instead:
# -D __u64="unsigned long long" \
# -D __s64="__signed__ long long" \
# -D __le64="unsigned long long" \
# -D __be64="__signed__ long long"

    LD_LIBRARY_PATH=$PREFIX/lib \
      make -j${MAKE_JOBS} || exit 1
    make install
fi

if [[ ${HOST} =~ .*darwin.* ]]; then

    # Avoid Xcode
    cp "${RECIPE_DIR}"/xcrun .
    cp "${RECIPE_DIR}"/xcodebuild .
    # Some test runs 'clang -v', but I do not want to add it as a requirement just for that.
    ln -s "${PREFIX}"/bin/${HOST}-clang++ ${HOST}-clang
    # Qt passes clang flags to LD (e.g. -stdlib=c++)
    export LD=${CXX}
    PATH=${PWD}:${PATH}

    ./configure -prefix $PREFIX \
                -libdir $PREFIX/lib \
                -bindir $PREFIX/bin \
                -headerdir $PREFIX/include/qt \
                -archdatadir $PREFIX \
                -datadir $PREFIX \
                -L $PREFIX/lib \
                -I $PREFIX/include \
                -R $PREFIX/lib \
                -release \
                -opensource \
                -confirm-license \
                -shared \
                -nomake examples \
                -nomake tests \
                -verbose \
                -skip enginio \
                -skip location \
                -skip sensors \
                -skip serialport \
                -skip serialbus \
                -skip quickcontrols2 \
                -skip wayland \
                -skip canvas3d \
                -skip 3d \
                -system-libjpeg \
                -system-libpng \
                -system-zlib \
                -qt-freetype \
                -qt-pcre \
                -c++11 \
                -no-framework \
                -no-dbus \
                -no-mtdev \
                -no-harfbuzz \
                -no-xinput2 \
                -no-xcb-xlib \
                -no-libudev \
                -no-egl \
                -no-openssl \
                -sdk macosx10.9
    ####
    make -j${MAKE_JOBS} module-qtwebengine || exit 1
    if find . -name "libQt5WebEngine*dylib" -exec false {} +; then
      echo "Did not build qtwebengine, exiting"
      exit 1
    fi
    make -j${MAKE_JOBS} || exit 1
    make install

    # Avoid Xcode (2)
    mkdir -p "${PREFIX}"/bin/xc-avoidance || true
    cp "${RECIPE_DIR}"/xcrun "${PREFIX}"/bin/xc-avoidance/
    cp "${RECIPE_DIR}"/xcodebuild "${PREFIX}"/bin/xc-avoidance/

fi


# Post build setup
# ----------------
# Remove static libraries that are not part of the Qt SDK.
pushd "${PREFIX}"/lib > /dev/null
    find . -name "*.a" -and -not -name "libQt*" -exec rm -f {} \;
popd > /dev/null

# Add qt.conf file to the package to make it fully relocatable
cp "${RECIPE_DIR}"/qt.conf "${PREFIX}"/bin/
if [[ ${target_platform} == osx-64 ]]; then
  mkdir -p "${PREFIX}"/python.app/Contents/MacOS || true
  cp "${RECIPE_DIR}"/qt.conf "${PREFIX}"/python.app/Contents/MacOS/
fi
