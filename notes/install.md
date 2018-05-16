## Installation
Largely followed: https://kozikow.com/2016/06/03/installing-and-configuring-arch-linux-on-thinkpad-x1-carbon/#Base-installation-of-Arch-Linux

```shell
# increase font in hidpi
setfont /usr/share/kbd/consolefonts/latarcyrheb-sun3

# connect to internet (assuming wireless)
iw dev
wifi-menu -o wlp2s0

# LUKS --> LVM
# format/create a parition for the pv
parted /dev/nvme0n1
# encrypt new partition -- lots of options, I went most secure
cryptsetup luksFormat --type luks2 -s 512 -h sha512 /dev/nvme0n1p5

# decrypt/open the partition so we can set up LVM
cryptsetup open /dev/nvme0n1p5 cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate x1 /dev/mapper/cryptlvm

# logical volumes: need swap for hibernate, don't allocate 100% (will need some for snapshots)
# unclear to me how much space we actually need here, so guessed.
lvcreate -L 8G x1 -n swap
# large root partition but w/e. bits are cheap.
lvcreate -L 50G x1 -n root 
lvcreate -L 300G x1 -n home

# filesystems
mkfs.ext4 /dev/x1/root
mkfs.ext4 /dev/x1/home
mkswap /dev/x1/swap

# labels, this is (mostly) useless
e2label /dev/x1/root root
e2label /dev/x1/home home
swaplabel -L swap /dev/x1/swap

# mount, fstab
mount /dev/x1/root /mnt
mkdir /mnt/home
mount /dev/x1/home /mnt/home
swapon /dev/x1/swap
# mount the EFI boot partition
mount /dev/nvme0n1p1 /mnt/boot

# install
# includes pkg for intel microcode updates (https://wiki.archlinux.org/index.php/Microcode#Enabling_Intel_microcode_updates)
pacstrap -i /mnt base base-devel intel-ucode vim zsh iw dialog wpa_supplicant net-tools iproute
# consider also including: gnome xorg-server xorg-xinit gnome-extra gnome-tweak-tool bluetoothctl bluez-utils htop iftop git

# fstab
genfstab -U /mnt >> /mnt/etc/fstab

# enter system, continue setup
arch-chroot /mnt /bin/bash

# time
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
tzselect

# keyboard
echo KEYMAP=us > /etc/vconsole.conf
echo FONT=latarcyrheb-sun32 >> /etc/vconsole.conf

# ramdisk
# modify HOOKs in: /etc/mkinitcpio.conf
HOOKS=(base udev autodetect modconf encrypt lvm2 resume shutdown suspend block filesystems keyboard keymap fsck)
mkinitcpio -p linux # ensure you see everything above

# systemd bootloader
cd /boot
bootctl install

cat << EOF > /boot/loader/loader.conf
timeout 4
default arch
editor 0
EOF

# note this includes the ramdisk for intel-ucode. make sure that pkg was installed and file exists
# unsure of UUID? run blkid
cat << EOF > /boot/loader/entries/arch.conf
title	Arch Linux
linux	/vmlinuz-linux
initrd  /intel-ucode.img
initrd	/initramfs-linux.img
options	root=UUID=<root_uuid> rw cryptdevice=UUID=<crypto_LUKS UUID>:cryptlvm root=/dev/x1/root resume=/dev/x1/swap
EOF

# set root passwd & reboot
passwd && reboot

# users/groups
useradd -m jaryd
passwd jaryd
groupadd sudo
vim /etc/sudoers # enable sudoers group
usermod -aG sudo jaryd

# systemctl
systemctl enable gdm.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service

# bugfixes
# localedef (for Gnome terminal bug)
localedef -f UTF-8 -i en_US en_US.UTF-8 

# prevent gdm from starting 2nd instance of pulseaudio
mkdir -p  /var/lib/gdm/.config/systemd/user
ln -s /dev/null  /var/lib/gdm/.config/systemd/user/pulseaudio.socket
```
