#/bin/sh

NAME="nuc"
DISK="/dev/sda"
BOOT="${DISK}1"
DATA="${DISK}2"
ROOT="/dev/mapper/vg0-root"
HOME="/dev/mapper/vg0-home"

setupConsole()
{
	loadkeys de-latin1
	setfont ter-132b
}

setupDisk()
{
	parted ${DISK} mklabel gpt
	parted --align=min ${DISK} unit MiB mkpart primary fat32 1 301
	parted --align=min ${DISK} unit MiB mkpart primary ext4 301 100%
	parted ${DISK} set 1 esp on
	parted ${DISK} set 2 lvm on
	parted ${DISK} unit s print
}

setupFilesys()
{
	mkfs.fat -F 32 ${BOOT}
	pvcreate  ${DATA}
	vgcreate vg0 ${DATA}
	lvcreate --size 50G --name root vg0
	lvcreate --size 50G --name home vg0
	mkfs.ext4 ${ROOT}
	mkfs.ext4 ${HOME}
}

mountFilesys()
{
	mount ${ROOT} /mnt
	mount --mkdir ${BOOT} /mnt/boot
	mount --mkdir ${HOME} /mnt/home
}

umountFilesys()
{
	umount /mnt/home
	umount /mnt/boot
	umount /mnt
}

setupPacstrap()
{
	pacstrap -K /mnt base linux linux-firmware
	genfstab -U /mnt >> /mnt/etc/fstab
}

setupLocale()
{
	ln -s /usr/share/zoneinfo/Europe/Berlin /etc/localtime
	hwclock --systohc

	sed --in-place=org -e 's,#de_DE.UTF,de_DE.UTF,' -e 's,#en_US.UTF,en_US.UTF,' /etc/locale.gen
	locale-gen

	echo 'LANG=en_US.UTF-8' > /etc/locale.conf
	echo 'KEYMAP=de-latin1' > /etc/vconsole.conf
	echo ${NAME} > /etc/hostname
}

setupPackages()
{
	pacman -S vim grub efibootmgr openssh lvm2
}

setupInitcpio()
{
	# HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)
	sed --in-place=org -e 's,block filesystem,block lvm2 filesystem' /etc/mkinitcpio.conf
	mkinitcpio -P
}

setupGrub()
{
	#grub-install /dev/sda
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch-Linux-grub
	grub-mkconfig -o /boot/grub/grub.cfg
}

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

setupSshd()
{
	systemctl enable sshd.service
	systemctl start sshd.service
}


for ARG in $*
do
	case "${ARG}" in
		con*)
			setupConsole
			;;
		disk)
			setupDisk
			;;
		mkfs)
			setupFilesys
			;;
		mount)
			mountFilesys
			;;
		umount)
			umountFilesys
			;;
		pacs)
			setupPacstrap
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
		pkg*)
			setupPackages
			;;
		net*)
			setupNetwork
			;;
		sshd)
			setupSshd
			;;
		*)
			echo "usage: $0 step1 step2 ..."
			echo ""
			echo "pre-mount:"
			echo "  console   setup console"
			echo "  disk      create partitions on ${DISK}"
			echo "  mkfs      create filesystems"
			echo "  mount     mount filesystems"
			echo "  pacstrap  pacstrap base, linux, firmware; make fstab"
			echo ""
			echo "arch-chroot /mnt:"
			echo "  locale    setup Europe/Berlin, de-latin1"
			echo "  pkg       install packages like lvm2, grub, vim, openssh, ..."
			echo "  initcpio  setup initial ramdisk"
			echo "  grub      setup bootloader grub2"
			echo "  umount    unmount filesystems"
			echo ""
			echo "after reboot:"
			echo "  network   enable systemd-networkd and resolvd"
			echo "  sshd      enable sshd"
			exit 2
			;;
	esac
done

