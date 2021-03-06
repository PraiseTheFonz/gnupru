#!/bin/bash

# Sample script to build the GCC PRU toolchain.

# On which upstream commits to apply patches. I frequently rebase so
# expect these to be somewhat random.
GCC_BASECOMMIT=c4d336f9d7a205c57820c17a993ecff6fa1db924
BINUTILS_BASECOMMIT=f30d5c78faa5979fb933038923e5270b7728f96f
NEWLIB_BASECOMMIT=e0f24404b3fcfa2c332ae14c3934546c91be3f42

GCC_GIT=https://github.com/mirrors/gcc
BINUTILS_GIT=https://github.com/bminor/binutils-gdb
NEWLIB_GIT=https://github.com/bminor/newlib

# If you have already checked out GCC or binutils, then references
# could save you some bandwidth
#GCC_GIT_REFERENCE="--single-branch --reference=$HOME/projects/misc/gcc"
#BINUTILS_GIT_REFERENCE="--single-branch --reference=$HOME/projects/misc/binutils-gdb"
#NEWLIB_GIT_REFERENCE="--single-branch --reference=$HOME/projects/misc/newlib"

MAINDIR=`pwd`
PATCHDIR=`pwd`/patches
SRC=`pwd`/src
BUILD=`pwd`/build
PREFIX=$HOME/bin/pru-gcc

die()
{
  echo ERROR: $@
  exit 1
}

prepare_source()
{
  local PRJ=$1
  local URL=$2
  local COMMIT=$3
  local REF="$4"
  wget $URL/archive/$COMMIT.tar.gz -O $SRC/"$PRJ"-"$COMMIT".tar.gz
  if [ $? -eq 0 ]; then
    cd $SRC
    tar -xvf "$PRJ"-"$COMMIT".tar.gz
    mv "$PRJ"-"$COMMIT" $PRJ
    cd $PRJ
    git init . && git add . && git commit -m "Import."
  else
    git clone --single-branch $URL $SRC/$PRJ $REF|| die Could not clone $URL
    cd $SRC/$PRJ
    git checkout -b tmp-pru $COMMIT || die Could not checkout $PRJ commit $COMMIT
  fi
  ls $PATCHDIR/$PRJ | sort | while read PATCH
  do
    git am -3 < $PATCHDIR/$PRJ/$PATCH || die "Could not apply patch $PATCH for $PRJ"
  done
  cd $MAINDIR
}

build_binutils()
{
  cd $BUILD/binutils-gdb
  $SRC/binutils-gdb/configure --target=pru --prefix=$PREFIX --disable-nls || die Could not configure Binutils
  make -j4 || die Could not build Binutils
  make install || die Could not install Binutils
}


build_gcc_pass()
{
  PASS=$1
  EXTRA_ARGS=$2
  cd $BUILD/gcc
  $SRC/gcc/configure --target=pru --prefix=$PREFIX --disable-nls --with-newlib --with-bugurl="https://github.com/dinuxbg/gnupru/issues" $EXTRA_ARGS || die Could not configure GCC pass$PASS
  make -j4 || die Could not build GCC pass$PASS
  make install || die Could not install GCC pass$PASS
}

build_newlib()
{
  cd $BUILD/newlib
  $SRC/newlib/configure --target=pru --prefix=$PREFIX --disable-newlib-fvwrite-in-streamio --enable-newlib-nano-formatted-io --disable-newlib-multithread || die Could not configure Newlib
  make -j4 || die Could not build Newlib
  make install || die Could not install Newlib
}

RETDIR=`pwd`

export PATH=$PREFIX/bin:$PATH

[ -d $SRC ] && die Incremental builds not supported. Cleanup and retry, e.g. 'git clean -fdx'
mkdir -p $SRC
mkdir -p $BUILD/gcc
mkdir -p $BUILD/binutils-gdb
mkdir -p $BUILD/newlib

# Checkout baseline and apply patches.
prepare_source binutils-gdb $BINUTILS_GIT $BINUTILS_BASECOMMIT "$BINUTILS_GIT_REFERENCE"
prepare_source gcc $GCC_GIT $GCC_BASECOMMIT "$GCC_GIT_REFERENCE"
prepare_source newlib $NEWLIB_GIT $NEWLIB_BASECOMMIT "$NEWLIB_GIT_REFERENCE"

# Configure, build and install.
build_binutils
build_gcc_pass 1 "--without-headers --enable-languages=c"
build_newlib
build_gcc_pass 2 "--enable-languages=c,c++"

cd $RETDIR

echo Done.
