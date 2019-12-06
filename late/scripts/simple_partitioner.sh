#!/bin/bash -ex
#
#       <simple_partitioner.sh>
#
#       Creates a simple partition layout
#
#       Copyright 2020 Dell Inc.
#           Mario Limonciello <Mario_Limonciello@Dell.com>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

DEVICE=$1
ESP_PART=$2
OS_PART=$3
GROUP=dell_lvm

#create new ones in free space
sfdisk --force -a ${DEVICE} <<EOF
-,- V
EOF

#setup LVM
partprobe
if [ -d /dev/${GROUP} ]; then
    dmsetup remove_all
fi
dd if=/dev/zero of=${DEVICE}${OS_PART} bs=512 count=4096
pvcreate -ff -y ${DEVICE}${OS_PART}
vgcreate -y ${GROUP} ${DEVICE}${OS_PART}
lvcreate -y -L 500M ${GROUP} -n boot
lvcreate -y -l 100%FREE ${GROUP} -n rootfs
mkfs.ext4 /dev/${GROUP}/boot
BOOT_UUID=`blkid /dev/${GROUP}/boot -s UUID -o value`

#setup LUKS
echo -n "password" > /tmp/key
cryptsetup luksFormat /dev/${GROUP}/rootfs < /tmp/key
LUKS_UUID=`blkid /dev/${GROUP}/rootfs -s UUID -o value`
cryptsetup luksOpen /dev/${GROUP}/rootfs decrypted_rootfs --key-file /tmp/key
mkfs.ext4 /dev/mapper/decrypted_rootfs
DECRYPTED_UUID=`blkid /dev/mapper/decrypted_rootfs -s UUID -o value`

#mount the disks
mkdir -p /target
mount /dev/mapper/decrypted_rootfs /target
mkdir -p /target/boot
mount /dev/${GROUP}/boot /target/boot
mkdir -p /target/boot/efi
mount ${DEVICE}${ESP_PART} /target/boot/efi
ESP_UUID=`blkid ${DEVICE}${ESP_PART} -s UUID -o value`

#create swapfile
available=$(df -P /target/ | sed 1d | while read fs size used available usep mounted on; do
	echo $available
done)
size=$((available/100))
size=$((size*5))
limit=$((1024*2048))
if [ $size -gt $limit ]
then
    size=$limit
fi
fallocate -l ${size}KiB /target/swapfile
dd if=/dev/zero of=/target/swapfile bs=1024 count=$size
chmod 600 /target/swapfile
mkswap /target/swapfile
swapon /target/swapfile

#write out fstab
mkdir -p /target/etc
cat > /target/etc/fstab << EOF
UUID=$DECRYPTED_UUID /              ext4    errors=remount-ro 0       1
UUID=$BOOT_UUID /boot               ext4    errors=remount-ro 0       1
UUID=$ESP_UUID /boot/efi            vfat    umask=0077      0       1
EOF
cat > /target/etc/crypttab << EOF
decrypted_rootfs UUID=$LUKS_UUID none luks,initramfs
EOF

#copy key into target (will be discarded later)
mkdir -p /target/tmp
cp /tmp/key /target/tmp/key
