echo off

echo "Patching up qtwebengine -b %webengine_version% ..."
pushd qtwebengine

unix2dos "%RECIPE_DIR%"\0003-win.patch
unix2dos "%RECIPE_DIR%"\0004-win8.patch

patch -p1 -i "%RECIPE_DIR%"\0003-win.patch
patch -p1 -i "%RECIPE_DIR%"\0004-win8.patch

popd


