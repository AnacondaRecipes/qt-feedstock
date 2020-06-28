@echo on
setlocal EnableDelayedExpansion
set SHORT_VERSION=%PKG_VERSION:~0,-2%

:: You might need to follow this advice if attempting to build on VS2019 against the v142 toolset:
:: https://developercommunity.visualstudio.com/content/problem/518592/2019-fatal-error-c1083-cannot-open-include-file-at.html

:: You may not always want this when doing dirty builds (debugging late stage
:: problems, but if debugging configure time issues you probably do want this).
if exist config.cache del config.cache

:: if "%DXSDK_DIR%" == "" (
::   echo You do not appear to have the DirectX SDK installed.  Please get it from
::   echo    https://www.microsoft.com/en-us/download/details.aspx?id=6812
::   echo and try this build again.  If you have installed it, and are still seeing
::   echo this message, please open a new console to refresh your environment variables.
::   exit /b 1
:: )

:: Webengine requires either working OpenGL drivers or
:: Angle (therefore DirectX >= 11). This works on some
:: VMs and not others.  Windows 7 VirtualBox instantly
:: aborts when loading Spyder sSo we've had to disable
:: it globally.
:: Using Mesa from MSYS2 is mentioned as a workaround:
::  http://wiki.qt.io/Cross-compiling-Mesa-for-Windows
:: `set QT_OPENGL=software` forces Qt5 to use that but
:: but when I tried it it was too buggy; Spyder crashed a
:: little bit later, though it worked for Carlos.
set WEBBACKEND=qtwebengine
set QT_LIBINFIX=_conda

where perl.exe
if %ERRORLEVEL% neq 0 (
  echo Could not find perl.exe
  exit /b 1
)

:: make sure we can find ICU and openssl:
set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"

:: Support systems with neither capable OpenGL (desktop mode) nor DirectX 11 (ANGLE mode) drivers
:: https://github.com/ContinuumIO/anaconda-issues/issues/9142
if not exist "%LIBRARY_BIN%" mkdir "%LIBRARY_BIN%"
copy opengl32sw\opengl32sw.dll  %LIBRARY_BIN%\opengl32sw.dll
if errorlevel 1 exit /b 1
if not exist %LIBRARY_BIN%\opengl32sw.dll exit /b 1

:: WebEngine (Chromium) specific definitions.  Only build this with VS 2015 (no support for python < 3.5)
if "%WEBBACKEND%" == "qtwebengine" (
  echo "Building qtwebengine"
) else (
  rmdir /s /q qtwebengine
)

set OPENGLVER=dynamic

:: Patch does not apply cleanly.  Copy file.
:: https://codereview.qt-project.org/#/c/141019/
copy %RECIPE_DIR%\tst_compiler.cpp qtbase\tests\auto\other\compiler\

:: Cannot skip this if we want QT_LIBINFIX to work.
:: TODO: should we always be rebuilding configure.exe anyway
:: Mentioned patch no longer applied
:: goto SKIP_REBUILD_CONFIGURE_EXE
:: If applying 0009-Win32-Re-permit-fontconfig-and-qt-freetype.patch (or
:: any patch that changes configureapp.cpp or any of the bootstrap files
:: in any way that alters the configure result) then configure.exe needs
:: to be rebuilt. Here I duplicate logic from configure.bat because that
:: file conflates needing to rebuild configure.exe with using a git repo
:: clone (OK, we should really remove that conflation instead and always
:: just rebuild configure.exe).
pushd qtbase
del /q configure.exe
set QTSRC=%CD%\
pushd qmake
set make=jom
set QTVERSION=%PKG_VERSION%
for /f "tokens=1,2,3,4 delims=.= " %%i in ('echo Qt.%QTVERSION%') do (
    set QTVERMAJ=%%j
    set QTVERMIN=%%k
    set QTVERPAT=%%l
)
:: .. end of specifically this bit is untested
echo #### Generated by bld.bat - DO NOT EDIT! ####> Makefile
echo/>> Makefile
set 
echo QMAKESPEC = win32-msvc>> Makefile
echo QT_VERSION = %QTVERSION%>> Makefile
rem These must have trailing spaces to avoid misinterpretation as 5>>, etc.
echo QT_MAJOR_VERSION = %QTVERMAJ% >> Makefile
echo QT_MINOR_VERSION = %QTVERMIN% >> Makefile
echo QT_PATCH_VERSION = %QTVERPAT% >> Makefile
echo CXX = cl.exe>>Makefile
:: This is a hack, CFLAGS_CRT becomes part of CFLAGS_EXTRA, overwriting it.
echo CFLAGS_CRT = -DQT_LIBINFIX=\"%QT_LIBINFIX%\" >> Makefile
echo EXTRA_CXXFLAGS =>>Makefile
rem This must have a trailing space.
echo QTSRC = %QTSRC% >> Makefile
echo SOURCE_PATH = %QTSRC% >> Makefile
echo INC_PATH = %QTSRC%\include >> Makefile
set tmpl=win32
echo/>> Makefile
type Makefile.%tmpl% >> Makefile
%make%
:: Attempt to avoid:
:: warning C4651: '/DQT_LIBINFIX="_conda"' specified for precompiled header but not for current compile
:: del qmake_pch.h
del qmake_pch.obj
del qmake_pch.pch
popd
popd
:SKIP_REBUILD_CONFIGURE_EXE

:: See http://doc-snapshot.qt-project.org/qt5-5.4/windows-requirements.html
:: this needs to be CALLed due to an exit statement at the end of configure:
:: optimized-tools is necessary for qtlibinfix, otherwise:
:: qtbase/lib/Qt5Bootstrap.prl
:: ends up containing:
:: QMAKE_PRL_TARGET = Qt5Bootstrap.condad.lib
:: for some odd reason.
call configure ^
     -prefix %LIBRARY_PREFIX% ^
     -libdir %LIBRARY_LIB% ^
     -bindir %LIBRARY_BIN% ^
     -headerdir %LIBRARY_INC%\qt ^
     -archdatadir %LIBRARY_PREFIX% ^
     -datadir %LIBRARY_PREFIX% ^
     -optimized-tools ^
     -L %LIBRARY_LIB% ^
     -I %LIBRARY_INC% ^
     -confirm-license ^
     -no-fontconfig ^
     -icu ^
     -no-separate-debug-info ^
     -no-warnings-are-errors ^
     -nomake examples ^
     -nomake tests ^
     -no-warnings-are-errors ^
     -opengl %OPENGLVER% ^
     -opensource ^
     -openssl ^
     -openssl-runtime ^
     -platform win32-msvc ^
     -release ^
     -shared ^
     -qt-freetype ^
     -system-libjpeg ^
     -system-libpng ^
     -system-sqlite ^
     -system-zlib ^
     -plugin-sql-sqlite ^
     -qtlibinfix %QT_LIBINFIX% ^
     -verbose

if %errorlevel% neq 0 exit /b %errorlevel%

:: re-enable echoing which is disabled by configure
echo on

:: To get a much quicker turnaround you can add this: (remember also to add the hat symbol after -plugin-sql-sqlite)
::     -skip %WEBBACKEND% -skip qtwebsockets -skip qtwebchannel -skip qtwayland -skip qtwinextras -skip qtsvg -skip qtsensors ^
::     -skip qtcanvas3d -skip qtconnectivity -skip declarative -skip multimedia -skip qttools

jom -U release
:: Hooray for racey build systems. You may get a failure about a QtWebengine .stamp file being missing. You may not. Who knows?
jom -U release
:: Stupidy we see an attempt *by* C:\qt5b\qt-5.15.0_17\_h_env\Library\bin\qmake.exe to copy a non-existant C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\qmake.exe on-top of itself!
::  cd qmake\ && ( if not exist Makefile.qmake-aux C:\qt5b\qt-5.15.0_17\work\qtbase\bin\qmake.exe -o Makefile.qmake-aux C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\qmake-aux.pro ) && C:\qt5b\qt-5.15.0_17\_build_env\jom.exe -f Makefile.qmake-aux install
::  C:\qt5b\qt-5.15.0_17\_build_env\jom.exe -f Makefile.qmake-aux.Release install
::  C:\qt5b\qt-5.15.0_17\work\qtbase\bin\qmake.exe -install qinstall -exe C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\qmake.exe C:\qt5b\qt-5.15.0_17\_h_env\Library\bin\qmake.exe
::    Error copying C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\qmake.exe to C:\qt5b\qt-5.15.0_17\_h_env\Library\bin\qmake.exe: Cannot open C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\qmake.exe for input
::    jom: C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\Makefile.qmake-aux.Release [install_qmake] Error 3
::    jom: C:\qt5b\qt-5.15.0_17\work\qtbase\qmake\Makefile.qmake-aux [release-install] Error 2
:: if %errorlevel% neq 0 exit /b %errorlevel%

if exist %LIBRARY_BIN%\qmake.exe goto ok_qmake_exists
  echo WARNING :: %LIBRARY_BIN%\qmake.exe does not exist jom -U install failed, very strange. See comment in bld.bat.
  echo WARNING :: Copying it from qtbase\bin\qmake.exe and re-running 'jom -U release' but with '-K' to keep going.
  copy qtbase\bin\qmake.exe %LIBRARY_BIN%\qmake.exe
  jom -U -K release
:ok_qmake_exists

echo Finished `jom -U release`
jom -U install
:: I expect raciness here too:
jom -U install
if %errorlevel% eq 0 goto ok_we_made_it
  echo ERROR :: Could not get a final `jom -U install` to work. Bailing ..
  exit /b %errorlevel%
:ok_we_made_it
echo INFO :: Finished `jom -U install`
pushd qtbase
  jom -U install_mkspecs
  if %errorlevel% neq 0 exit /b %errorlevel%
  echo Finished `jom -U install_mkspecs`
popd

:: To rewrite qt.conf contents per conda environment
if not exist %PREFIX%\Scripts mkdir %PREFIX%\Scripts
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if %errorlevel% neq 0 exit /b %errorlevel%
