# 所有执行的命令都打印到终端
set -x
# 如果执行过程中有非0退出状态，则立即退出
set -e
# 引用未定义变量则立即退出
set -u

help | head -n 1
uname

MSYS2_PATH="/C/msys64"

if [[ $# -ge 1 ]]; then
  if [[ $1 != "x86" && $1 != "x64" && $1 != "arm64" ]]; then
    echo "invalid params: build.sh [x86/x64/arm64]"
    exit 1
  fi
  ARCH="$1"
else
  ARCH="x64"
fi

# 定义平台变量
case "$(uname)" in
"Linux")
  BUILD_PLATFORM="linux"
  LIB_TYPE="static"
  ;;

"Darwin")
  BUILD_PLATFORM="mac"
  LIB_TYPE="shared"
  ;;

"MINGW"*|"MSYS_NT"*)
  BUILD_PLATFORM="win"
  LIB_TYPE="shared"
  ;;
*)
  echo "Unknown OS"
  exit 1
  ;;
esac

# https://ffmpeg.org/download.html#releases
FFMPEG_VERSION=n4.4.2
INSTALL_NAME="ffmpeg-$FFMPEG_VERSION-$BUILD_PLATFORM-$ARCH-$LIB_TYPE.zip"

if [ ! -d "ffmpeg" ]; then
  git clone -b $FFMPEG_VERSION https://git.ffmpeg.org/ffmpeg.git ffmpeg
fi

# install dependencies
case "$(uname)" in
"Linux")
  sudo apt-get update -qq && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libgnutls28-dev \
  libmp3lame-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  meson \
  ninja-build \
  pkg-config \
  texinfo \
  wget \
  yasm \
  zlib1g-dev

  sudo apt install libunistring-dev libaom-dev

  sudo apt-get install nasm

  sudo apt-get install libx264-dev

  ;;

"Darwin")
  sudo chown -R `whoami`:admin /usr/local/share
  sudo chown -R `whoami`:admin /usr/local/opt
  sudo chown -R `whoami`:admin /usr/local/bin
  brew install automake fdk-aac git lame libass libtool libvorbis libvpx \
    opus shtool texi2html theora wget x264 x265 xvid nasm
  ;;

"MINGW"*|"MSYS_NT"*)
  MINGW_ARCH="mingw-w64-x86_64"
  if [[ $ARCH == "x86" ]]; then
    MINGW_ARCH="mingw-w64-i686"
  fi

  pacman -S --needed --noconfirm make nasm yasm diffutils pkgconf p7zip
  if [[ "$(uname)" == "MINGW"* ]]; then
    pacman -S --needed --noconfirm $MINGW_ARCH-gcc

    # pacman packages include x264: https://packages.msys2.org/search?q=264
    # pacman -S --needed --noconfirm $MINGW_ARCH-x264
  fi
  ;;

*)
  echo "Unknown OS"
  exit 1
  ;;
esac

# http://ffmpeg.xianwaizhiyin.net/compile-ffmpeg/x264.html
# 关于ffmepg引入x264编解码器总结：
# 1. h264解码ffmepg自带的有
# 2. h264编码可以用外部库（例如x264）或者操作系统本地库（例如windows mediafoundation）
# 3. ffmpeg可以动态/静态依赖x264
# 4. x264可以用不同平台的本地工具安装（例如apt/brew/pacman），但都是动态库，一般相关头文件库文件安装好以后ffmpeg就可以找到
# 5. 如果需要静态依赖x264可以自己编译x264，并通过--extra-cflags和--extra-ldflags给ffmpeg指定x264的头文件和库文件路径
# 6. windows下使用msvc编译ffmpeg的话，没有合适的x264安装工具，需要自己编译x264（无论动态、静态依赖x264）

BUILD_X264="false"
buildx264() {
  if [ ! -d "x264" ]; then
    git clone -b stable https://code.videolan.org/videolan/x264.git
  fi

  pushd x264
    if [[ "$(uname)" == "MSYS_NT"* ]]; then
      CC=cl ./configure --prefix=../x264_install --enable-static
    else
      if [[ $ARCH == "x86" ]]; then
        # 264 auto detect host is wrong on x86, manual set
        ./configure --prefix=../x264_install --host=msys --enable-static
      else
        ./configure --prefix=../x264_install --enable-static
      fi
    fi

    make -j8 && make install
  popd
}

if [[ "$BUILD_X264" == "true" ]]; then
  buildx264
fi

pushd ffmpeg

# Standard options
CONFIGURE_OPTIONS="--prefix=../ffmpeg_install"

# Licensing options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-gpl --enable-version3 --enable-nonfree"

# Configuration options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-runtime-cpudetect --disable-autodetect"
if [[ $LIB_TYPE == "shared" ]]; then
    CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-shared --disable-static"
fi

# Program options
#CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-programs"

# Documentation options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-doc"

# Component options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-postproc --disable-network --disable-pthreads"

# Individual component options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-everything --enable-decoder=h264 --enable-parser=h264 --enable-demuxer=h264"
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-muxer=mp4 --enable-protocol=file"
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-decoder=opus --enable-decoder=aac"

# External library support
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-zlib --disable-iconv --disable-sdl2"
# use x264 encoder
#CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --enable-libx264"

# Toolchain options
if [[ "$(uname)" == "MSYS_NT"* ]]; then
    CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --toolchain=msvc"
fi
# static link libgcc_s_dw2-1.dll
EXTRA_LDFLAGS=
if [[ "$(uname)" == "MINGW"* ]]; then
  EXTRA_LDFLAGS="-static-libgcc"
fi
# link x264
EXTRA_CFLAGS=
if [[ "$BUILD_X264" == "true" ]]; then
  EXTRA_CFLAGS="-I../x264_install/include"
  # msvc use -LIBPATH:
  if [[ "$(uname)" == "MSYS_NT"* ]]; then
      EXTRA_LDFLAGS="$EXTRA_LDFLAGS -LIBPATH:../x264_install/lib"
  else
      EXTRA_LDFLAGS="$EXTRA_LDFLAGS -L../x264_install/lib"
  fi
fi

# Developer options
CONFIGURE_OPTIONS="$CONFIGURE_OPTIONS --disable-debug"

./configure $CONFIGURE_OPTIONS --extra-cflags="$EXTRA_CFLAGS" --extra-ldflags="$EXTRA_LDFLAGS"
make -j8
make install

popd

# process dylib load path and long version 
if [[ "$(uname)" == "Darwin" ]]; then
# change $1 all LC_LOAD_DYLIB from $2 to @loader_path/*
changeAllLLD() {
    lines=$(otool -l $1 | grep LC_LOAD_DYLIB -A2 | grep $2 || true)
    if [ -z "$lines" ]; then
        return
    fi
    OLD_IFS="$IFS"
    IFS=$'\n'
    array=($lines)
    for line in ${array[@]}
    do
        right=$(echo ${line#*name })
        full_name=$(echo ${right% \(offset*})
        name=$(basename ${full_name})

        install_name_tool -change $full_name @loader_path/$name $1
    done
    IFS="$OLD_IFS"
}

removeAllVersion() {
    lines=$(ls *.dylib)
    OLD_IFS="$IFS"
    IFS=$' '
    array=($lines)
    IFS=$'\n'
    array=($array)
    for line in ${array[@]}
    do
        short_name=$(echo ${line%.*.*.*})
        mv $line ${short_name}.dylib
        changeAllLLD ${short_name}.dylib ffmpeg_install
        # change LC_ID_DYLIB
        install_name_tool -id "@loader_path/${short_name}.dylib" ${short_name}.dylib
    done
    IFS="$OLD_IFS"
}

pushd ./ffmpeg_install/lib

find ./ -type l -delete
removeAllVersion

popd
fi

# windows mingw need copy some dll
if [[ "$(uname)" == "MINGW"* ]]; then
  if [[ $ARCH == "x86" ]]; then
    cp $MSYS2_PATH/mingw32/bin/libwinpthread-1.dll ./ffmpeg_install/bin
  else
    cp $MSYS2_PATH/mingw64/bin/libwinpthread-1.dll ./ffmpeg_install/bin
  fi
fi

7z a ./$INSTALL_NAME ./ffmpeg_install/*
echo "${INSTALL_NAME}" > INSTALL_NAME
