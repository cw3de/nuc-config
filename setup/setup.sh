#/bin/sh
#
# setup arch linux to the point where ansible can take over
#
# see:
# https://wiki.archlinux.org/title/Installation_guide
#
# Encryption see:
# https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
#

# change here
MY_HOST_NAME="xxx" # change to your host name
MY_USER_NAME="xx" # change to your user name
MY_DISK="/dev/sdX" # change to your disk
MY_VOL_GROUP="vg0" # change volume group, if needed
MY_TIMEZONE="Europe/Berlin" # change to your time zone
MY_KEYBOARD="de-latin1" # change to your keyboard layout
MY_LANGUAGE="en_US.UTF-8" # change to your language
MY_LOCALES="${MY_LANGUAGE} de_DE.UTF-8" # add extra locales here

BOOT="${MY_DISK}1"
DATA="${MY_DISK}2"
ROOT="/dev/mapper/${MY_VOL_GROUP}-root"
SWAP="/dev/mapper/${MY_VOL_GROUP}-swap"
HOME="/dev/mapper/${MY_VOL_GROUP}-home"
DOCKER="/dev/mapper/${MY_VOL_GROUP}-docker"

# install (before chroot): console
setupConsole()
{
	loadkeys "${MY_KEYBOARD}"
	setfont ter-132b
}

# install (before chroot): part
setupPartitions()
{
	# https://www.gnu.org/software/parted/manual/html_node/index.html
	# align partitions to 4MiB (8192 sectors of 512 bytes)
	parted --script ${MY_DISK} mklabel gpt
	parted --script --align=optimal ${MY_DISK} mkpart EFI fat32 '4MiB' '300MiB'
	parted --script --align=optimal ${MY_DISK} mkpart LVM ext4 '300MiB' '100%'
	parted --script ${MY_DISK} set 1 esp on
	parted --script ${MY_DISK} set 2 lvm on
	parted --script ${MY_DISK} unit s print
}

# install (before chroot): mkfs
setupFilesys()
{
	mkfs.fat -F 32 ${BOOT}
	pvcreate  ${DATA}
	vgcreate ${MY_VOL_GROUP} ${DATA}
	lvcreate --size 50G --name root ${MY_VOL_GROUP}
	lvcreate --size 16G --name swap ${MY_VOL_GROUP}
	lvcreate --size 50G --name home ${MY_VOL_GROUP}
	lvcreate --size 50G --name docker ${MY_VOL_GROUP}
	mkfs.ext4 ${ROOT}
	mkswap ${SWAP}
	mkfs.ext4 ${HOME}
	mkfs.ext4 ${DOCKER}
}

# install (before chroot): pacstrap
setupPacstrap()
{
	pacstrap -K /mnt base linux linux-firmware
	genfstab -U /mnt >> /mnt/etc/fstab
}

# install (before chroot): mount
mountFilesys()
{
	mount ${ROOT} /mnt
	mount --mkdir ${BOOT} /mnt/boot
	mount --mkdir ${HOME} /mnt/home
	mount --mkdir ${DOCKER} /mnt/var/lib/docker
	swapon ${SWAP}
}

# before reboot (optional): umount
umountFilesys()
{
	swapoff ${SWAP}
	umount /mnt/var/lib/docker
	umount /mnt/home
	umount /mnt/boot
	umount /mnt
}

# after chroot: locale
setupLocale()
{
	ln -sf "/usr/share/zoneinfo/${MY_TIMEZONE}" /etc/localtime
	hwclock --systohc

	# enable de_DE.UTF-8 and en_US.UTF-8
	for LCNAME in ${MY_LOCALES}
	do
		sed --in-place=org -e "s,#${LCNAME},${LCNAME}," /etc/locale.gen
	done
	locale-gen

	echo "LANG=${MY_LANGUAGE}" > /etc/locale.conf
	echo "KEYMAP=${MY_KEYBOARD}" > /etc/vconsole.conf
	echo "${MY_HOST_NAME}" > /etc/hostname
}

# after chroot: ramdisk
setupRamdisk()
{
	# consider adding mkinitcpio-firmware from AUR to get rid of the warnings
	pacman -S lvm2
	# add lvm2 to the HOOKS in for mkinitcpio
	echo > /etc/mkinitcpio.conf.d/lvm2.conf "HOOKS+=(lvm2)"
	mkinitcpio -P
}

# after chroot: grub
setupGrub()
{
	pacman -S grub efibootmgr
	# MSDOS
	# grub-install ${MY_DISK}
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch-Linux-grub
	grub-mkconfig -o /boot/grub/grub.cfg
}

# after reboot: update
updatePackages()
{
	pacman -Syu
}

# after reboot: user
setupUser()
{
	useradd -m -G wheel -s /bin/bash ${MY_USER_NAME}
	passwd ${MY_USER_NAME}
}

# after reboot: network
setupNetwork()
{
	(
	echo "[Match]"
	echo "Name=eno1"
	echo ""
	echo "[Network]"
	echo "DHCP=yes"
	) > /etc/systemd/network/20-wired.network
	systemctl enable systemd-networkd.service
	systemctl enable systemd-resolved.service
	systemctl start systemd-networkd.service
	systemctl start systemd-resolved.service
}

# after reboot: sshd
setupSshd()
{
	pacman -S openssh
	systemctl enable sshd.service
	systemctl start sshd.service
	useradd ${MY_USER_NAME}
	echo "copy your ssh key to ${MY_USER_NAME}@${MY_HOST_NAME}"
}

# after reboot: sudo
setupSudo()
{
	pacman -S sudo
	echo "${MY_USER_NAME}  ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USER_NAME}
}

# after reboot: python
setupPython()
{
	pacman -S python
}

showUsage()
{
	echo "usage: $0 step1 step2 ..."
	echo ""
	echo "pre-mount:"
	echo "  console   setup console"
	echo "  part      create partitions on ${MY_DISK}"
	echo "  mkfs      create filesystems"
	echo "  mount     mount filesystems"
	echo "  pacstrap  pacstrap base, linux, firmware; make fstab"
	echo ""
	echo "arch-chroot /mnt:"
	echo "  locale    setup ${MY_TIMEZONE}, ${MY_LANGUAGE}, ${MY_KEYBOARD}"
	echo "  ramdisk   setup initial ramdisk with mkinitcpio"
	echo "  grub      setup bootloader grub2"
	echo "  umount    unmount filesystems"
	echo ""
	echo "after reboot:"
	echo "  update    update packages"
	echo "  user 	  create user ${MY_USER_NAME}"
	echo "  network   enable systemd-networkd and resolvd"
	echo "  sshd      enable sshd"
	echo "  sudo      setup sudo"
	echo "  python    setup python, so we can continue with ansible"
}

if [ $# -eq 0 ]
then
	showUsage
	exit 0
fi

for ARG in $*
do
	case "${ARG}" in
		c|console)
			setupConsole
			;;
		grub)
			setupGrub
			;;
		h|help)
			showUsage
			exit 0
			;;
		l|locale)
			setupLocale
			;;
		mkfs)
			setupFilesys
			;;
		m|mount)
			mountFilesys
			;;
		network)
			setupNetwork
			;;
		pacstrap)
			setupPacstrap
			;;
		part)
			setupPartitions
			;;
		python)
			setupPython
			;;
		ramdisk)
			setupRamdisk
			;;
		sshd)
			setupSshd
			;;
		sudo)
			setupSudo
			;;
		u|umount)
			umountFilesys
			;;
		update)
			updatePackages
			;;
		user)
			setupUser
			;;
		*)
			echo "unknown argument: ${ARG}"
			exit 2
			;;
	esac
done

