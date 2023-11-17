#/bin/sh
#
# setup arch linux to the point where ansible can take over
#
# Encryption see:
# https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
#

MY_HOST_NAME="xxx" # change to your host name
MY_USER_NAME="xxx" # change to your user name
MY_DISK="/dev/sdX" # change to your disk
MY_VOL_GROUP="vgX" # change to your volume group

BOOT="${MY_DISK}1"
DATA="${MY_DISK}2"
ROOT="/dev/mapper/${MY_VOL_GROUP}-root"
SWAP="/dev/mapper/${MY_VOL_GROUP}-swap"
HOME="/dev/mapper/${MY_VOL_GROUP}-home"

# install (before chroot)
setupConsole()
{
	loadkeys de-latin1
	setfont ter-132b
}

# install (before chroot)
setupPartitions()
{
	# https://www.gnu.org/software/parted/manual/html_node/index.html
	# align partitions to 4MiB (8192 sectors of 512 bytes)
	parted --script ${MY_DISK} mklabel gpt
	parted --script --align=optimal ${MY_DISK} mkpart EFI fat32 '4MiB' '400MiB'
	parted --script --align=optimal ${MY_DISK} mkpart LVM ext4 '400MiB' '100%'
	parted --script ${MY_DISK} set 1 esp on
	parted --script ${MY_DISK} set 2 lvm on
	parted --script ${MY_DISK} unit s print
}

# install (before chroot)
setupFilesys()
{
	mkfs.fat -F 32 ${BOOT}
	pvcreate  ${DATA}
	vgcreate ${MY_VOL_GROUP} ${DATA}
	lvcreate --size 50G --name root ${MY_VOL_GROUP}
	lvcreate --size 16G --name swap ${MY_VOL_GROUP}
	lvcreate --size 50G --name home ${MY_VOL_GROUP}
	mkfs.ext4 ${ROOT}
	mkswap ${SWAP}
	mkfs.ext4 ${HOME}
}

# install (before chroot)
setupPacstrap()
{
	pacstrap -K /mnt base linux linux-firmware
	genfstab -U /mnt >> /mnt/etc/fstab
}

# install (before chroot)
mountFilesys()
{
	mount ${ROOT} /mnt
	mount --mkdir ${BOOT} /mnt/boot
	mount --mkdir ${HOME} /mnt/home
}

# before reboot (optional)
umountFilesys()
{
	umount /mnt/home
	umount /mnt/boot
	umount /mnt
}

# after chroot
setupLocale()
{
	ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
	hwclock --systohc

	sed --in-place=org -e 's,#de_DE.UTF,de_DE.UTF,' -e 's,#en_US.UTF,en_US.UTF,' /etc/locale.gen
	locale-gen

	echo 'LANG=en_US.UTF-8' > /etc/locale.conf
	echo 'KEYMAP=de-latin1' > /etc/vconsole.conf
	echo ${MY_HOST_NAME} > /etc/hostname
}

# after chroot
setupInitcpio()
{
	pacman -S lvm2
	# HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)
	sed --in-place=org -e 's,block filesystem,block lvm2 filesystem' /etc/mkinitcpio.conf
	mkinitcpio -P
}

# after chroot
setupGrub()
{
	pacman -S grub efibootmgr
	# MSDOS
	# grub-install ${MY_DISK}
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch-Linux-grub
	grub-mkconfig -o /boot/grub/grub.cfg
}

# after reboot
setupUser()
{
	useradd -m -G wheel -s /bin/bash ${MY_USER_NAME}
	passwd ${MY_USER_NAME}
}

# after reboot
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

# after reboot
setupSshd()
{
	pacman -S openssh
	systemctl enable sshd.service
	systemctl start sshd.service
	useradd ${MY_USER_NAME}
	echo "copy your ssh key to ${MY_USER_NAME}@${MY_HOST_NAME}"
}

# after reboot
setupSudo()
{
	pacman -S sudo
	echo "${MY_USER_NAME}  ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/${MY_USER_NAME}
}

# after reboot
setupAnsible()
{
	pacman -S ansible
}

for ARG in $*
do
	case "${ARG}" in
		con*)
			setupConsole
			;;
		part)
			setupPartitions
			;;
		mkfs)
			setupFilesys
			;;
		pacs)
			setupPacstrap
			;;
		mount)
			mountFilesys
			;;
		umount)
			umountFilesys
			;;
		loc*)
			setupLocale
			;;
		init*)
			setupInitcpio
			;;
		grub)
			setupGrub
			;;
		user)
			setupUser
			;;
		net*)
			setupNetwork
			;;
		sshd)
			setupSshd
			;;
		sudo)
			setupSudo
			;;
		ansi*)
			setupAnsible
			;;
		*)
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
			echo "  locale    setup Europe/Berlin, de-latin1"
			echo "  initcpio  setup initial ramdisk"
			echo "  grub      setup bootloader grub2"
			echo "  umount    unmount filesystems"
			echo ""
			echo "after reboot:"
			echo "  user 	  create user ${MY_USER_NAME}"
			echo "  network   enable systemd-networkd and resolvd"
			echo "  sshd      enable sshd"
			echo "  sudo      setup sudo"
			echo "  ansible   setup ansible"
			exit 2
			;;
	esac
done

