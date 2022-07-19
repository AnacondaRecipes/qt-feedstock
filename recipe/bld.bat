echo off

mkdir %SYSTEMDRIVE%\tmp

git config --system core.longpaths true

echo "Fetching qtwebengine -b %webengine_version% ..."

git clone -b "%webengine_version%" --recurse-submodules https://code.qt.io/cgit/qt/qtwebengine.git

if %ERRORLEVEL% neq 0 (
  echo Could not checkout git repository
  exit /b 1
)

echo "Patching up qtwebengine -b %webengine_version% ..."
pushd qtwebengine

unix2dos "%RECIPE_DIR%"\0003-win.patch
unix2dos "%RECIPE_DIR%"\0004-win8.patch

patch -p1 -i "%RECIPE_DIR%"\0003-win.patch
patch -p1 -i "%RECIPE_DIR%"\0004-win8.patch

popd


