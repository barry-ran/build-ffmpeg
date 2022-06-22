@echo off

set MSYS2_PATH=C:/msys64
:: gethub action vc path
set VCVARSALL="C:/Program Files (x86)/Microsoft Visual Studio/2019/Enterprise/VC/Auxiliary/Build/vcvarsall.bat"
if not exist %VCVARSALL% (
    :: my pc vc path
    set VCVARSALL="D:/Program Files (x86)/Microsoft Visual Studio/2019/Community/VC/Auxiliary/Build/vcvarsall.bat"
)

set ARCH=x64
set MINGW_ARCH=mingw64
:: MSYS: build use msys2+msvc
:: mingw32/mingw64: build use msys2+mingw
set MSYSTEM=MSYS
if "%1"=="x86" (
    set ARCH=x86
    set MINGW_ARCH=mingw32
)
if "%2"=="MINGW" (
    set MSYSTEM=%MINGW_ARCH%
)

if "%MSYSTEM%"=="MSYS" (
    call %VCVARSALL% %ARCH%
)
:: a good way to integrate vcvarsall.bat and msys2
set PATH=%MSYS2_PATH%/usr/bin;%MSYS2_PATH%/%MINGW_ARCH%/bin;%PATH%
bash build.sh %ARCH%