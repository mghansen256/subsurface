#!/bin/bash

# build Subsurface for Win32
#
# this file assumes that you have installed MXE on your system
# and installed a number of dependencies as well
#
# cd ~/src/win
# git clone https://github.com/mxe/mxe
# cd mxe
# make libxml2 libxslt libusb1 qt5
#
# after qtbase has finished building you need to edit
# ~/src/win/mxe/usr/i686-w64-mingw32.shared/qt5/mkspecs/qconfig.pri
# and add the following line at the top:
# MINGW_IN_SHELL = 1
# (of course without the leading '#')
# then you can enable the QtWebKit build by editing
# ~/src/win/mxe/src/qtwebkit.mk and changing the "disabled" define to read
#
# define $(PKG)_BUILD_SHARED
#     # looks for build tools with .exe suffix and tries to use win_flex
#     $(SED) -i 's,\.exe,,' '$(1)/Tools/qmake/mkspecs/features/functions.prf'
# ...
#
# and remove the empty definition of $(PKG)_BUILD_SHARED below
#
# Do all this in a separate terminal while the build is still running :-)
# After quite a while (depending on your machine anywhere from 15-20
# minutes to several hours) you should have a working MXE install in
# ~/src/win/mxe
#
# Now this script will come in:
#
# This makes some assumption about the filesystem layout based
# on the way things are setup on my system so I can build Ubuntu PPA,
# OBS and Windows out of the same sources.
# Something like this:
#
# ~/src/win/mxe                    <- current MXE git with Qt5, automake (see above)
#      /win/libzip                 <- libzip sources from their latest distribution tar ball
#      /win/grantlee               <- Grantlee 5.0.0 sources from git
#      /win/libssh2                <- from git - v1.6 seems to work
#      /win/libcurl                <- from git - 7.42.1 seems to work
#      /win/subsurface             <- current subsurface git
#      /win/libdivecomputer        <- appropriate libdc/Subsurface-branch branch
#      /win/marble-source          <- appropriate marble/Subsurface-branch branch
#      /win/libgit2                <- libgit2 0.23.1 or similar
#
# ~/src/win/win32                  <- build directory
#
# then start this script from ~/src/win/win32
#
#  cd ~/src/win/win32
#  bash ../../subsurface/packaging/windows/mxe-based-build.sh installer
#
# this should create the latest daily installer
#
# in order not to keep recompiling everything this script only compiles
# the other components if their directories are missing or if a "magic
# file" has been touched.
#
# so if you update one of the other libs do
#
# cd ~/src/win/win32
# touch build.<component>
# bash ../../subsurface/packaging/windows/mxe-based-build.sh installer
#
# and that component gets rebuilt as well. E.g.
# touch build.libdivecomputer
# to rebuild libdivecomputer before you build Subsurface
#
# please send patches / additions to this file!
#

exec 1> >(tee ./winbuild.log) 2>&1

# for debugging
#trap "set +x; sleep 1; set -x" DEBUG

# this is run on a rather powerful machine - if you want less
# build parallelism, please change this variable
JOBS="-j12"
BASEDIR=$(cd "`dirname $0`/.."; pwd)
BUILDDIR=$(cd "`dirname $0`"; pwd)

if [[ ! -d $BASEDIR/mxe ]] ; then
	echo "Please start this from the right directory "
	echo "usually a winbuild directory parallel to the mxe directory"
	exit 1
fi

echo "Building in $BUILDDIR ..."

export PATH=$BASEDIR/mxe/usr/bin:$PATH:$BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/bin/


# grantlee

cd $BUILDDIR
if [[ ! -d grantlee || -f build.grantlee ]] ; then
	rm -f build.grantlee
	mkdir -p grantlee
	cd grantlee
	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_TESTS=OFF \
		$BASEDIR/grantlee

	make $JOBS
	make install
fi


# libssh2:

cd $BUILDDIR
if [[ ! -d libssh2 || -f build.libssh2 ]] ; then
	rm -f build.libssh2
	mkdir -p libssh2
	cd libssh2

	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_TESTING=OFF \
		-DBUILD_SHARED_LIBS=ON \
		$BASEDIR/libssh2
	make $JOBS
	make install
	# don't install your dlls in bin, please
	cp $BASEDIR/mxe/usr/i686-w64-mingw32.shared/bin/libssh2.dll $BASEDIR/mxe/usr/i686-w64-mingw32.shared/lib
fi


# libcurl

cd $BUILDDIR
if [[ ! -d libcurl || -f build.libcurl ]] ; then
	rm -f build.libcurl
	mkdir -p libcurl
	cd libcurl
	../../libcurl/configure --host=i686-w64-mingw32.shared \
		--prefix=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/ \
		--disable-ftp \
		--disable-ldap \
		--disable-ldaps \
		--disable-rtsp \
		--enable-proxy \
		--enable-dict \
		--disable-telnet \
		--disable-tftp \
		--disable-pop3 \
		--disable-imap \
		--disable-smb \
		--disable-smtp \
		--disable-gopher \
		--disable-manual \
		--with-libssh2=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/

	# now remove building the executable
	sed -i 's/SUBDIRS = lib src include/SUBDIRS = lib include/' Makefile

	make $JOBS
	make install
fi


# libzip

cd $BUILDDIR
if [[ ! -d libzip || -f build.libzip ]] ; then
	rm -f build.libzip
	mkdir -p libzip
	cd libzip
#	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
#		-DCMAKE_BUILD_TYPE=Release \
#		$BASEDIR/libzip
	$BASEDIR/libzip/configure --host=i686-w64-mingw32.shared --prefix=$BASEDIR/mxe/usr/i686-w64-mingw32.shared
	make $JOBS
	make install
fi


# libgit2:

cd $BUILDDIR
if [[ ! -d libgit2 || -f build.libgit2 ]] ; then
	rm -f build.libgit2
	mkdir -p libgit2
	cd libgit2
	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
		-DBUILD_CLAR=OFF -DTHREADSAFE=ON \
		-DDLLTOOL=$BASEDIR/mxe/usr/bin/i686-w64-mingw32.shared-dlltool \
		$BASEDIR/libgit2
	make $JOBS
	make install
fi

# libdivecomputer
#
# this one is special because we want to make sure it's in sync
# with the Linux builds, but we don't want the autoconf files cluttering
# the original source directory... so the $BASEDIR/libdivecomputer is
# a local clone of the "real" libdivecomputer directory

cd $BUILDDIR
if [[ ! -d libdivecomputer || -f build.libdivecomputer ]] ; then
	rm build.libdivecomputer
	cd $BASEDIR/libdivecomputer
	git pull
	cd $BUILDDIR
	mkdir -p libdivecomputer
	cd libdivecomputer

	$BASEDIR/libdivecomputer/configure --host=i686-w64-mingw32.shared \
		--enable-static --disable-shared \
		--prefix=$BASEDIR/mxe/usr/i686-w64-mingw32.shared
	make $JOBS
	make install
else
	echo ""
	echo ""
	echo "WARNING!!!!"
	echo ""
	echo "libdivecoputer not rebuilt!!"
	echo ""
	echo ""
fi

# marble:

cd $BUILDDIR
if [[ ! -d marble || -f build.marble ]] ; then
	rm build.marble
	mkdir -p marble
	cd marble
	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
		-DCMAKE_PREFIX_PATH=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5 \
		-DQTONLY=ON -DQT5BUILD=ON \
		-DBUILD_MARBLE_APPS=OFF -DBUILD_MARBLE_EXAMPLES=OFF \
		-DBUILD_MARBLE_TESTS=OFF -DBUILD_MARBLE_TOOLS=OFF \
		-DBUILD_TESTING=OFF -DWITH_DESIGNER_PLUGIN=OFF \
		-DBUILD_WITH_DBUS=OFF \
		$BASEDIR/marble-source
	make $JOBS
	make install
	# what the heck is marble doing?
	mv $BASEDIR/mxe/usr/i686-w64-mingw32.shared/libssrfmarblewidget.dll $BASEDIR/mxe/usr/i686-w64-mingw32.shared/lib
fi

###############
# finally, Subsurface

cd $BUILDDIR
mkdir -p subsurface/staging/plugins
cd subsurface/staging/plugins
cp -a $BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/plugins/iconengines .
cp -a $BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/plugins/imageformats .
cp -a $BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/plugins/platforms .
cp -a $BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/plugins/printsupport .

cd $BUILDDIR/subsurface

if [[ "$1" == "qmake" ]] ; then
	shift
	export objdump=$BASEDIR/mxe/usr/bin/i686-w64-mingw32.shared-objdump

	i686-w64-mingw32.shared-qmake-qt5 \
		LIBMARBLEDEVEL=../marble \
		LIBGIT2DEVEL=../libgit2 CONFIG+=libgit21-api \
		CROSS_PATH=$BASEDIR/mxe/usr/i686-w64-mingw32.shared \
		QMAKE_LRELEASE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/bin/lrelease \
		SPECIAL_MARBLE_PREFIX=1 \
		MAKENSIS=i686-w64-mingw32.shared-makensis \
		$BASEDIR/../subsurface/subsurface.pro

#		LIBDCDEVEL=../libdivecomputer \

else
	cmake -DCMAKE_TOOLCHAIN_FILE=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/share/cmake/mxe-conf.cmake \
		-DCMAKE_PREFIX_PATH=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5 \
		-DCMAKE_BUILD_TYPE=Release \
		-DQT_TRANSLATION_DIR=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/qt5/translations \
		-DMAKENSIS=i686-w64-mingw32.shared-makensis \
		-DUSE_LIBGIT23_API=1 \
		-DLIBDIVECOMPUTER_INCLUDE_DIR=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/include \
		-DLIBDIVECOMPUTER_LIBRARIES=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/lib/libdivecomputer.a \
		-DMARBLE_INCLUDE_DIR=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/include \
		-DMARBLE_LIBRARIES=$BASEDIR/mxe/usr/i686-w64-mingw32.shared/lib/libssrfmarblewidget.dll \
		$BASEDIR/subsurface
	#sed -i 's@-lssh2@/home/hohndel/src/win/win32/libgit2/libssh2.dll@g' CMakeFiles/subsurface.dir/link.txt
fi


make $JOBS $@
