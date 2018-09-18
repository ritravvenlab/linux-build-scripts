# Copyright (c) 2018 krtkl inc. [R.Bush]
# Modified by ritravvenlab      [D.Kaputa]
# 
# Snickerdoodle SD Card Build Script
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published by
# the Free Software Foundation.
#

# sample use: ./build_script.sh all
# note that running 'all' does not create the custom fsbl or the custom device tree.
# 'all' is like when you order 'the works' on your sub but they don't give you the hot peppers
# the custom-device-tree and custom-fsbl sections require that you modify the associated .tcl
# files as they require a Vivado projec in the correct location to work.

#!/bin/bash
UBOOT_SOURCE_URL=https://github.com/Xilinx/u-boot-xlnx.git
LINUX_SOURCE_URL=https://github.com/Xilinx/linux-xlnx.git
DTS_SOURCE_URL=https://github.com/ritravvenlab/snickerdoodle-dts.git
DTC_SOURCE_URL=https://github.com/ritravvenlab/dtc.git
WL18XX_FW_SOURCE_URL=https://github.com/ritravvenlab/wl18xx_fw.git
WLCONF_SOURCE_URL=https://github.com/ritravvenlab/wlconf.git
XILINX_DEVICE_TREE=https://github.com/ritravvenlab/device-tree-xlnx

rootdir=$(pwd)
rootfs=$rootdir/ubuntu-armhf
cd $rootdir

# Need to do this a better way: Add this to /etc/bash.bashrc or ~/.bashrc
source /opt/Xilinx/SDK/2017.4/settings64.sh
export PATH=/opt/Xilinx/SDK/2017.4/gnu/aarch32/lin/gcc-arm-none-eabi/bin:$PATH   

#
# Grab sources
#
get_sources(){
# Download the U-Boot source
git clone $UBOOT_SOURCE_URL

# Download the Linux source
#git clone $LINUX_SOURCE_URL

# Download device tree compiler source
#git clone $DTC_SOURCE_URL
#git clone $DTS_SOURCE_URL

# Download supplementary wireless firmware
#git clone $WL18XX_FW_SOURCE_URL

# Download wirless configuration utility
#git clone $WLCONF_SOURCE_URL
}

#
# Bootstrap the filesystem
#
bootstrap_system() {

debootstrap --verbose --foreign --arch armhf xenial $rootfs

cp /usr/bin/qemu-arm-static $rootfs/usr/bin/

LANG=C chroot $rootfs/ /debootstrap/debootstrap --second-stage

# Configure filesystem

# Set up FSTAB
cat > $rootfs/etc/fstab << "EOF"
# Default snickerdoodle File System Table
# <file system>    <mount>    <type>    <options>  <dump>  <pass>
/dev/mmcblk0p1    /boot    vfat    defaults  0  0
/dev/mmcblk0p2    /    ext4    defaults  0  0
configfs    /config    configfs  defaults  0  0
tmpfs      /tmp    tmpfs    defaults  0  0

EOF

#-------------------------------------------------------------------------------
# Configure networking
#-------------------------------------------------------------------------------

# Set the hostname
cat > $rootfs/etc/hostname << "EOF"
snickerdoodle
EOF

cat > $rootfs/etc/hosts << "EOF"
127.0.0.1  localhost snickerdoodle
::1    localhost ip6-localhost ip6-loopback
fe00::0    ip6-localnet
ff00::0    ip6-mcastprefix
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters

EOF
}

# ROS?
#if false; then

# Set up sources list
#cat << EOF > $rootfs/etc/apt/sources.list.d/ros-latest.list
#deb http://packages.ros.org/ros/ubuntu xenial main"
#EOF

# Set up keys
#apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116
#fi


configure_networking() {

cat > $rootfs/etc/network/interfaces << "EOF"
auto lo
iface lo inet loopback

source-directory /etc/network/interfaces.d

EOF

if [ ! -d $rootfs/etc/network/interfaces.d ]; then
  mkdir $rootfs/etc/network/interfaces.d
fi

cat > $rootfs/etc/resolv.conf << "EOF"
nameserver 8.8.8.8
EOF

# Wireless station
cat > $rootfs/etc/network/interfaces.d/wlan0 << "EOF"
allow-hotplug wlan0

iface wlan0 inet dhcp
  wpa-driver nl80211
  wpa-conf /etc/wpa_supplicant.conf

EOF

# Wireless access point
cat > $rootfs/etc/network/interfaces.d/wlan1 << "EOF"
auto wlan1

iface wlan1 inet static
  address 10.0.110.2
  netmask 255.255.255.0
  hostapd /etc/hostapd.conf

EOF

chmod 0600 $rootfs/etc/network/interfaces
chmod 0600 $rootfs/etc/network/interfaces.d/*

cat > $rootfs/etc/wpa_supplicant.conf << "EOF"
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=0
update_config=1

#RIT
network={
	auth_alg=OPEN
	key_mgmt=NONE
	mode=0
	ssid="RIT-Legacy"
}

#HOME - uncomment and add in your password if working from home
#network={
#        auth_alg=OPEN
#        key_mgmt=WPA-PSK
#        psk="password"
#        ssid="NETGEAR26"
#        proto=RSN
#        mode=0
#}

EOF

chmod 0600 $rootfs/etc/wpa_supplicant.conf

# configure the DHCP server for the wireless access point
sed -i -e 's/^\(INTERFACES=\).*/\1\"wlan1\"/' /etc/default/isc-dhcp-server

mkdir -p $rootfs/etc/snickerdoodle/accesspoint

# Add script to bringup the wireless access point
cat > $rootfs/etc/snickerdoodle/accesspoint/ifupdown.sh << "EOF"
#!/bin/sh

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# On Debian GNU/Linux systems, the text of the GPL license,
# version 2, can be found in /usr/share/common-licenses/GPL-2.

# quit if we're called for lo
if [ "$IFACE" = lo ]; then
  exit 0
fi

# using hostapd config
if [ -n "$IF_HOSTAPD" ]; then
  HOSTAPD_CONF="$IF_HOSTAPD"
else
  exit 0
fi


accesspoint_msg () {
  case "$1" in
    verbose)
      shift
      echo "$HOSTAPD_PNAME: $@" > "$TO_NULL"
      ;;
    stderr)
      shift
      echo "$HOSTAPD_PNAME: $@" > /dev/stderr
      ;;
    *)
      ;;
    esac
}


init_accesspoint () {
  echo 1 > /proc/sys/net/ipv4/ip_forward

  if [ ! -d /sys/class/net/$IFACE ]; then
    iw phy `ls /sys/class/ieee80211/` interface add $IFACE type managed
  fi

  HWID=`sed '{s/://g; s/.*\([0-9a-fA-F]\{6\}$\)/\1/}' /sys/class/net/$IFACE/address`
  DEFAULT_SSID=`hostname`-$HWID

  if [ -z $(grep -e "^ssid *=.*" $HOSTAPD_CONF) ]; then
    if [ -n $(grep -e "^#ssid *=.*" $HOSTAPD_CONF) ]; then
      sed -ie "s/^#\(ssid *= *\).*$/\1$DEFAULT_SSID/g" $HOSTAPD_CONF
    fi
  fi
}

case "$MODE" in
  start)
    case "$PHASE" in
      pre-up)
        init_accesspoint || exit 1
        ;;
      *)
        accesspoint_msg stderr "unknown phase: \"$PHASE\""
        exit 1
        ;;
    esac
    ;;
  stop)
    case "$PHASE" in
      *)
        accesspoint_msg stderr "unknown phase: \"$PHASE\""
        exit 1
        ;;
    esac
    ;;
  *)
    accesspoint_msg stderr "unknown mode: \"$MODE\""
    exit 1
    ;;
esac

exit 0

EOF

chmod 755 $rootfs/etc/snickerdoodle/accesspoint/ifupdown.sh

# Link to the script for interface bringup
ln -s ../../snickerdoodle/accesspoint/ifupdown.sh ubuntu-armhf/etc/network/if-pre-up.d/accesspoint

# Default hostapd configuration

cat > $rootfs/etc/hostapd.conf << "EOF"

interface=wlan1
driver=nl80211
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
ctrl_interface=/var/run/hostapd
#ssid=
country_code=US
ieee80211d=1
ieee80211h=1
hw_mode=g
channel=11
beacon_int=100
dtim_period=2
max_num_sta=10
supported_rates=10 20 55 110 60 90 120 180 240 360 480 540
basic_rates=10 20 55 110 60 120 240
preamble=1
macaddr_acl=0
auth_algs=3
ignore_broadcast_ssid=0
tx_queue_data3_aifs=7
tx_queue_data3_cwmin=15
tx_queue_data3_cwmax=1023
tx_queue_data3_burst=0
tx_queue_data2_aifs=3
tx_queue_data2_cwmin=15
tx_queue_data2_cwmax=63
tx_queue_data2_burst=0
tx_queue_data1_aifs=1
tx_queue_data1_cwmin=7
tx_queue_data1_cwmax=15
tx_queue_data1_burst=3.0
tx_queue_data0_aifs=1
tx_queue_data0_cwmin=3
tx_queue_data0_cwmax=7
tx_queue_data0_burst=1.5
wme_enabled=1
uapsd_advertisement_enabled=1
wme_ac_bk_cwmin=4
wme_ac_bk_cwmax=10
wme_ac_bk_aifs=7
wme_ac_bk_txop_limit=0
wme_ac_bk_acm=0
wme_ac_be_aifs=3
wme_ac_be_cwmin=4
wme_ac_be_cwmax=10
wme_ac_be_txop_limit=0
wme_ac_be_acm=0
wme_ac_vi_aifs=2
wme_ac_vi_cwmin=3
wme_ac_vi_cwmax=4
wme_ac_vi_txop_limit=94
wme_ac_vi_acm=0
wme_ac_vo_aifs=2
wme_ac_vo_cwmin=2
wme_ac_vo_cwmax=3
wme_ac_vo_txop_limit=47
wme_ac_vo_acm=0
ap_max_inactivity=10000
disassoc_low_ack=1
ieee80211n=1
ht_capab=[SHORT-GI-20][GF]
wep_rekey_period=0
eap_server=1
own_ip_addr=127.0.0.1
wpa=2
wpa_passphrase=snickerdoodle
wpa_group_rekey=0
wpa_gmk_rekey=0
wpa_ptk_rekey=0
ap_table_max_size=255
ap_table_expiration_time=60
wps_state=2
ap_setup_locked=1
device_name=snickerdoodle
manufacturer=krtkl
model_name=TI_connectivity_module
model_number=wl18xx
config_methods=virtual_display virtual_push_button keypad

EOF
}

#
# Configure Wireless
#
configure_wireless() {
  make -C wlconf

  cd wlconf
  if [ ! -d $rootfs/lib/firmware/ti-connectivity ]; then
    mkdir -p $rootfs/lib/firmware/ti-connectivity
  fi

  ./wlconf -o $rootfs/lib/firmware/ti-connectivity/wl18xx-conf.bin -I official_inis/WL1837MOD_INI_FCC_CE.ini

  cd ..

  cp wl18xx_fw/wl18xx-fw-4.bin $rootfs/lib/firmware/ti-connectivity/wl18xx-fw-4.bin

  chmod 755 -R $rootfs/lib/firmware/ti-connectivity/
}

#
# Configure Packages
#
configure_packages() {

cat > $rootfs/etc/apt/sources.list << "EOF"
deb http://ports.ubuntu.com/ubuntu-ports xenial main universe

EOF

# Set up mount points
mount -t proc proc $rootfs/proc
mount -o bind /dev $rootfs/dev
mount -o bind /dev/pts $rootfs/dev/pts

#-------------------------------------------------------------------------------
# Install packages
#-------------------------------------------------------------------------------

packages="ethtool i2c-tools apache2 php libapache2-mod-php openssh-server crda iw wpasupplicant hostapd isc-dhcp-server isc-dhcp-client build-essential bison flex python3.5 iperf3 htop"

cat > $rootfs/third-stage << EOF
#!/bin/bash

apt update && apt upgrade
apt -y install git-core binutils ca-certificates initramfs-tools u-boot-tools
apt -y install locales console-common less nano git sudo manpages
apt -y install $packages
apt -y install vim
apt -y install ssh
apt -y install samba
apt -y install xrdp
apt -y autoremove

# Add default user
useradd -m -G sudo -U -p $(openssl passwd -crypt "snickerdoodle") snickerdoodle
#passwd -e snickerdoodle

rm -f /third-stage

EOF

chmod +x $rootfs/third-stage
LANG=C chroot $rootfs /third-stage

umount $rootfs/dev/pts
umount $rootfs/dev
umount $rootfs/proc
}

#
# Perform cleanup on the filesystem
#
cleanup_system() {

cat > $rootfs/cleanup << "EOF"
#!/bin/bash

rm -rf /root/.bash_history
apt update
apt clean
rm -f /cleanup
rm -f /usr/bin/qemu*

EOF

chmod +x $rootfs/cleanup
LANG=C chroot $rootfs /cleanup
}


#
# Build Device Tree
#
build_dtb() {
make -C $rootdir/dtc
export PATH=$rootdir/dtc:$PATH

cd $rootdir/snickerdoodle-dts
make
cd $rootdir
}


#
# U-Boot build process
#
build_u_boot() {
export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-
make -C $rootdir/u-boot-xlnx avnet_ultra96_rev1_defconfig
make -C $rootdir/u-boot-xlnx
export PATH=$rootdir/u-boot-xlnx/tools:$PATH
}

#
# Linux build process
#
build_kernel() {
export ARCH=arm
export CROSS_COMPILE=arm-none-eabi-
export LOADADDR=0x8000
export INSTALL_MOD_PATH=$rootfs
export INSTALL_HDR_PATH=$rootfs/usr
make -C $rootdir/snickerdoodle-linux snickerdoodle_defconfig
make -C $rootdir/snickerdoodle-linux uImage
make -C $rootdir/snickerdoodle-linux modules
make -C $rootdir/snickerdoodle-linux modules_install
make -C $rootdir/snickerdoodle-linux headers_install
}

#
# Create fsbl.elf
#
create_custom_fsbl() {
echo "Creating Custom FSBL"
cd $rootdir
hsi -mode tcl -source custom-fsbl.tcl  
}

#
# Create device tree
#
create_custom_device_tree() {
echo "Creating Custom Device Tree"
cd $rootdir 
hsi -mode tcl -source custom-device-tree.tcl  
}

#
# Create Boot.bin
#
create_boot() {
echo "Creating Boot.bin"
rm -rf $rootdir/bootfiles
mkdir $rootdir/bootfiles

cp $rootdir/fsbl.elf $rootdir/bootfiles/fsbl.elf
cp $rootdir/snickerdoodle-dts/snickerdoodle-black.dtb $rootdir/bootfiles/devicetree.dtb
cp $rootdir/snickerdoodle-u-boot/u-boot $rootdir/bootfiles/u-boot.elf
cp $rootdir/snickerdoodle-linux/arch/arm/boot/uImage $rootdir/bootfiles/uImage

cd $rootdir/bootfiles
cat > bootimage.bif << "EOF"
image : {
        [bootloader]fsbl.elf
        u-boot.elf
}
EOF

bootgen -image bootimage.bif -o boot.bin

# Set the configuration in the uEnv.txt file
cat > uEnv.txt << "EOF"
bootargs=console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait earlyprink
bitstream_image=system.bit
script_image=uboot.scr
script_load_address=0x4000000
uenvcmd=if test -e mmc 0 ${script_image}; then load mmc 0 ${script_load_address} ${script_image} && source ${script_load_address}; fi

EOF

cat > boot-scr << "EOF"
if test -e mmc 0 ${bitstream_image}; then
  echo Loading bitstream from ${bitstream_image}
  load mmc 0 ${loadbit_addr} ${bitstream_image} && fpga loadb 0 ${loadbit_addr} ${filesize};
else
  echo No bitstream present. Bitstream will not be loaded.
fi


if test -e mmc 0 ${kernel_image}; then
  fatload mmc 0 ${kernel_load_address} ${kernel_image};
  fatload mmc 0 ${devicetree_load_address} ${devicetree_image};
  if test -e mmc 0 ${ramdisk_image}; then
    fatload mmc 0 ${ramdisk_load_address} ${ramdisk_image};
    bootm ${kernel_load_address} ${ramdisk_load_address} ${devicetree_load_address};
  else
    bootm ${kernel_load_address} - ${devicetree_load_address};
  fi
fi
EOF

mkimage -A arm -T script -C none -n "Snickerdoodle Boot Script" -d boot-scr uboot.scr
}

create_card() {
cd $rootdir
 
dd conv=sync,noerror if=/dev/zero of=snickerdoodle.img bs=1M count=4096

#tune2fs -c0 -i0 snickerdoodle.img

parted snickerdoodle.img --script -- mklabel msdos
parted snickerdoodle.img --script -- mkpart primary fat32 1MiB 128MiB
parted snickerdoodle.img --script -- mkpart primary ext4 128MiB 100%

loopdevice=`losetup -f --show snickerdoodle.img`
device=`kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`

sleep 5

bootp="/dev/mapper/${device}p1"
rootp="/dev/mapper/${device}p2"

mkfs.vfat -n BOOT $bootp
mke2fs -t ext4 -L ROOTFS -b 4096 $rootp

bootmnt=$(mktemp -d bootXXXXXX)
rootmnt=$(mktemp -d rootXXXXXX)

mount $bootp $bootmnt
mount $rootp $rootmnt

rsync -Hav $rootdir/bootfiles/ $bootmnt/
rsync -Hav $rootfs/ $rootmnt/

sync

umount $bootmnt
umount $rootmnt

kpartx -dv $loopdevice
losetup -d $loopdevice

rm -r $bootmnt
rm -r $rootmnt
}

case "$1" in
get_sources)
  get_sources       || exit 1
  ;;
bootstrap_system)
  bootstrap_system  || exit 1
  ;;
cleanup_system)
  cleanup_system    || exit 1
  ;;
all)
  get_sources    || exit 1
  bootstrap_system  || exit 1
  configure_packages  || exit 1
  configure_wireless  || exit 1
  configure_networking  || exit 1
  cleanup_system    || exit 1
  build_u_boot    || exit 1
  build_kernel    || exit 1
  build_dtb    || exit 1
  create_boot    || exit 1
  create_card    || exit 1
  ;;
rootfs)
  bootstrap_system  || exit 1
  configure_packages  || exit 1
  configure_wireless  || exit 1
  configure_networking  || exit 1
  cleanup_system    || exit 1
  ;;
create_custom_fsbl)
  create_custom_fsbl    || exit 1
  ;;
create_custom_device_tree)
  create_custom_device_tree    || exit 1
  ;;
boot)
  build_u_boot    || exit 1
  build_kernel    || exit 1
  build_dtb       || exit 1
  create_boot     || exit 1
  ;;
create_card)
  create_card    || exit 1
  ;;
dsk_test)
  get_sources       || exit 1
  build_u_boot    || exit 1
  ;;
*)
  echo "ERROR: invalid command $1"
  exit  1
  ;;
esac
