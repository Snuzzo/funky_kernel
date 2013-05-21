#!/bin/bash -e

msg() {
    echo
    echo ==== $* ====
    echo
}
grep 'VERSION = ' "Makefile" >>build-config
grep 'PATCHLEVEL = ' "Makefile" >>build-config
grep 'SUBLEVEL = ' "Makefile" >>build-config
sed -i 's/VERSION = /MAIN=/g' build-config >> build-config
sed -i 's/PATCHLEVEL = /PATCHLEVEL=/g' build-config >> build-config
sed -i 's/SUBLEVEL = /SUBLEVEL=/g' build-config >> build-config
sed -i '/CKMAIN=/ d' build-config
sed -i '/KERNELMAIN=/ d' build-config
# -----------------------

. build-config

TOOLS_DIR=`dirname "$0"`
MAKE=$TOOLS_DIR/make.sh

# -----------------------

UPSTREAM="$MAIN.$PATCHLEVEL.$SUBLEVEL"
ZIP=$TARGET_DIR/$VERSION.zip
SHA1=$TOOLS_DIR/sha1.sh
FTP=$LOCAL_BUILD_DIR/ftp.sh
UPDATE_ROOT=$LOCAL_BUILD_DIR/update
KEYS=$LOCAL_BUILD_DIR/keys
CERT=$KEYS/certificate.pem
KEY=$KEYS/key.pk8
ANYKERNEL=$LOCAL_BUILD_DIR/kernel
GLOBAL=$LOCAL_BUILD_DIR/global
POSTBOOT=$LOCAL_BUILD_DIR/postboot
VIDEOFIX=$LOCAL_BUILD_DIR/videofix
UIFIX=$LOCAL_BUILD_DIR/uifix
ZIMAGE=arch/arm/boot/zImage
GOVERNOR=CONFIG_CPU_FREQ_DEFAULT_GOV_$DEFAULT_GOVERNOR
SCHEDULER=CONFIG_DEFAULT_$DEFAULT_SCHEDULER

msg Building: $VERSION
echo "   Defconfig:       $DEFCONFIG"
echo "   Local build dir: $LOCAL_BUILD_DIR"
echo "   Target dir:      $TARGET_DIR"
echo "   Tools dir:       $TOOLS_DIR"
echo
echo "   Target system partition: $SYSTEM_PARTITION"
echo

if [ -e $CERT -a -e $KEY ]
then
    msg Reusing existing $CERT and $KEY
else
    msg Regenerating keys, pleae enter the required information.

    (
	mkdir -p $KEYS
	cd $KEYS
	openssl genrsa -out key.pem 1024 && \
	openssl req -new -key key.pem -out request.pem && \
	openssl x509 -req -days 9999 -in request.pem -signkey key.pem -out certificate.pem && \
	openssl pkcs8 -topk8 -outform DER -in key.pem -inform PEM -out key.pk8 -nocrypt
    )
fi

if [ -e $UPDATE_ROOT ]
then
    rm -rf $UPDATE_ROOT
fi

if [ -e $LOCAL_BUILD_DIR/update.zip ]
then
    rm -f $LOCAL_BUILD_DIR/update.zip
fi

$MAKE $DEFCONFIG

perl -pi -e 's/(CONFIG_LOCALVERSION="[^"]*)/\1-'"$VERSION"'"/' .config
echo "$GOVERNOR=y" >> .config
echo "$SCHEDULER=y" >> .config
SCHEDULER=CONFIG_IOSCHED_$DEFAULT_SCHEDULER
echo "$SCHEDULER=y" >> .config

$MAKE -j$N_CORES

msg Kernel built successfully, building $ZIP

mkdir -p $UPDATE_ROOT/system/lib/modules
find . -name '*.ko' -exec cp {} $UPDATE_ROOT/system/lib/modules/ \;

mkdir -p $UPDATE_ROOT/META-INF/com/google/android
cp $TOOLS_DIR/update-binary $UPDATE_ROOT/META-INF/com/google/android

$SHA1

SUM=`sha1sum $ZIMAGE | cut --delimiter=' ' -f 1`
 
(
    cat <<EOF
$BANNER
EOF
  sed -e "s|@@SYSTEM_PARTITION@@|$SYSTEM_PARTITION|" \
      -e "s|@@FLASH_BOOT@@|$FLASH_BOOT|" \
      -e "s|@@SUM@@|$SUM|" \
      -e "s|@@VERSION@@|$VERSION|" \
      -e "s|@@UPSTREAM@@|$UPSTREAM|" \
      < $TOOLS_DIR/updater-script
) > $UPDATE_ROOT/META-INF/com/google/android/updater-script

mkdir -p $UPDATE_ROOT/kernel
mkdir -p $UPDATE_ROOT/global
mkdir -p $UPDATE_ROOT/postboot
mkdir -p $UPDATE_ROOT/videofix
mkdir -p $UPDATE_ROOT/uifix
mkdir -p $UPDATE_ROOT/lunarmenu
cp $ZIMAGE $UPDATE_ROOT/lunarmenu/zimage$VERSION
cp $ANYKERNEL/* $UPDATE_ROOT/kernel
cp $GLOBAL/* $UPDATE_ROOT/global
cp $POSTBOOT/* $UPDATE_ROOT/postboot
cp $VIDEOFIX/* $UPDATE_ROOT/videofix
cp $UIFIX/* $UPDATE_ROOT/uifix

(
    cd $UPDATE_ROOT
    zip -r ../update.zip .
)
java -jar $TOOLS_DIR/signapk.jar $CERT $KEY $LOCAL_BUILD_DIR/update.zip $ZIP
make mrproper
sed -i '/MAIN=/ d' build-config
sed -i '/PATCHLEVEL=/ d' build-config
sed -i '/SUBLEVEL=/ d' build-config
cp build-config $LOCAL_BUILD_DIR/build-config
cat banner >temp2
echo "<p>Latest version: <font color="#0000FF">$VERSION</p></font>" >>temp2
echo "<p><a style="'"color: #0ACF66"'" href=http://vp-zp.com/snuzzo$FTPTARGETDIR/$VERSION.zip>Quick-Click Download</a></p>" >>temp2
cat temp2 > ChangeLog.html
git log >> temp
sed -i -e 's/^/<p>/' temp
sed -i '/<p>commit/ d' temp
sed -i '/<p>Author/ d' temp
sed -i -e 's/Date:/<font color="#CF0A45">Date:/' temp
perl -ne 'chomp; printf "%s</p></font>\n", $_' < temp >> ChangeLog.html
echo "</div></body></html>" >> ChangeLog.html
rm temp2
rm temp
cp ChangeLog.html $TARGET_DIR/ChangeLog.html
$FTP
msg COMPLETE
