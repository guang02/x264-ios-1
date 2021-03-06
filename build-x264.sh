#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

ARCHS="arm64 armv7s x86_64 i386 armv7"

# directories
SOURCE="x264"
FAT="x264-iOS"

SCRATCH="scratch-x264"
# must be an absolute path
THIN=`pwd`/"thin-x264"

# the one included in x264 does not work; specify full path to working one
GAS_PREPROCESSOR=/usr/local/bin/gas-preprocessor.pl

COMPILE="y"
LIPO="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	SIMULATOR="-mios-simulator-version-min=7.0"
		    	HOST=
		    else
		    	SIMULATOR="-mios-simulator-version-min=5.0"
			HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    if [ $ARCH = "armv7s" ]
		    then
		    	CPU="--cpu=swift"
		    else
		    	CPU=
		    fi
		    SIMULATOR=
		    if [ $ARCH = "arm64" ]
		    then
		        HOST="--host=aarch64-apple-darwin"
		    else
		        HOST="--host=arm-apple-darwin"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future -arch $ARCH"
		CFLAGS="-arch $ARCH $SIMULATOR"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH"

		mkdir extras
		ln -s $GAS_PREPROCESSOR extras

		make -j3 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi
