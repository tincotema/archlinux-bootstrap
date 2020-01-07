#!/bin/bash

source "$GENTOO_BOOTSTRAP_DIR/scripts/protection.sh" || exit 1


################################################
# Functions

check_has_program() {
	type "$1" &>/dev/null \
		|| die "Missing program: '$1'"
}

sync_time() {
	einfo "Syncing time"
	ntpd -g -q \
		|| die "Could not sync time with remote server"

	einfo "Current date: $(LANG=C date)"
	einfo "Writing time to hardware clock"
	hwclock --systohc --utc \
		|| die "Could not save time to hardware clock"
}

check_config() {
	[[ "$KEYMAP" =~ ^[0-9A-Za-z-]*$ ]] \
		|| die "KEYMAP contains invalid characters"
}

prepare_installation_environment() {
	einfo "Preparing installation environment"

	check_config

	check_has_program gpg
	check_has_program hwclock
	check_has_program lsblk
	check_has_program ntpd
	check_has_program partprobe
	check_has_program python3
	check_has_program sgdisk
	check_has_program uuidgen
	check_has_program wget

	sync_time
}

partition_device_print_config_summary() {
	elog "-------- Partition configuration --------"
	elog "Device: [1;33m$PARTITION_DEVICE[m"
	elog "Existing partition table:"
	for_line_in <(lsblk -n "$PARTITION_DEVICE" \
		|| die "Error in lsblk") elog
	elog "New partition table:"
	elog "[1;33m$PARTITION_DEVICE[m"
	elog "├─efi   size=[1;32m$PARTITION_EFI_SIZE[m"
	if [[ "$ENABLE_SWAP" == true ]]; then
	elog "├─swap  size=[1;32m$PARTITION_SWAP_SIZE[m"
	fi
	elog "└─linux size=[1;32m[remaining][m"
	if [[ "$ENABLE_SWAP" != true ]]; then
	elog "swap: [1;31mdisabled[m"
	fi
}

partition_device() {
	[[ "$ENABLE_PARTITIONING" == true ]] \
		|| return 0

	einfo "Preparing partitioning of device '$PARTITION_DEVICE'"

	[[ -b "$PARTITION_DEVICE" ]] \
		|| die "Selected device '$PARTITION_DEVICE' is not a block device"

	partition_device_print_config_summary
	ask "Do you really want to apply this partitioning?" \
		|| die "For manual partitioning formatting please set ENABLE_PARTITIONING=false in config.sh"
	countdown "Partitioning in " 5

	einfo "Partitioning device '$PARTITION_DEVICE'"

	# Delete any existing partition table
	sgdisk -Z "$PARTITION_DEVICE" >/dev/null \
		|| die "Could not delete existing partition table"

	# Create efi/boot partition
	sgdisk -n "0:0:+$PARTITION_EFI_SIZE" -t 0:ef00 -c 0:"efi" -u 0:"$PARTITION_UUID_EFI" "$PARTITION_DEVICE" >/dev/null \
		|| die "Could not create efi partition"

	# Create swap partition
	if [[ "$ENABLE_SWAP" == true ]]; then
		sgdisk -n "0:0:+$PARTITION_SWAP_SIZE" -t 0:8200 -c 0:"swap" -u 0:"$PARTITION_UUID_SWAP" "$PARTITION_DEVICE" >/dev/null \
			|| die "Could not create swap partition"
	fi

	# Create system partition
	sgdisk -n 0:0:0 -t 0:8300 -c 0:"linux" -u 0:"$PARTITION_UUID_LINUX" "$PARTITION_DEVICE" >/dev/null \
		|| die "Could not create linux partition"

	# Print partition table
	einfo "Applied partition table"
	sgdisk -p "$PARTITION_DEVICE" \
		|| die "Could not print partition table"

	# Inform kernel of partition table changes
	partprobe "$PARTITION_DEVICE" \
		|| die "Could not probe partitions"
}

format_partitions() {
	[[ "$ENABLE_FORMATTING" == true ]] \
		|| return 0

	if [[ "$ENABLE_PARTITIONING" != true ]]; then
		einfo "Preparing to format the following partitions:"

		blkid -t PARTUUID="$PARTITION_UUID_EFI" \
			|| die "Error while listing efi partition"
		if [[ "$ENABLE_SWAP" == true ]]; then
			blkid -t PARTUUID="$PARTITION_UUID_SWAP" \
				|| die "Error while listing swap partition"
		fi
		blkid -t PARTUUID="$PARTITION_UUID_LINUX" \
			|| die "Error while listing linux partition"

		ask "Do you really want to format these partitions?" \
			|| die "For manual formatting please set ENABLE_FORMATTING=false in config.sh"
		countdown "Formatting in " 5
	fi

	einfo "Formatting partitions"

	local dev
	dev="$(get_device_by_partuuid "$PARTITION_UUID_EFI")" \
		|| die "Could not resolve partition UUID '$PARTITION_UUID_EFI'"
	einfo "  $dev (efi)"
	mkfs.fat -F 32 -n "efi" "$dev" \
		|| die "Could not format EFI partition"

	if [[ "$ENABLE_SWAP" == true ]]; then
		dev="$(get_device_by_partuuid "$PARTITION_UUID_SWAP")" \
			|| die "Could not resolve partition UUID '$PARTITION_UUID_SWAP'"
		einfo "  $dev (swap)"
		mkswap -L "swap" "$dev" \
			|| die "Could not create swap"
	fi

	dev="$(get_device_by_partuuid "$PARTITION_UUID_LINUX")" \
		|| die "Could not resolve partition UUID '$PARTITION_UUID_LINUX'"
	einfo "  $dev (linux)"
	mkfs.ext4 -q -L "linux" "$dev" \
		|| die "Could not create ext4 filesystem"
}

mount_by_partuuid() {
	local dev
	local partuuid="$1"
	local mountpoint="$2"

	# Skip if already mounted
	mountpoint -q -- "$mountpoint" \
		&& return

	# Mount device
	einfo "Mounting device partuuid=$partuuid to '$mountpoint'"
	mkdir -p "$mountpoint" \
		|| die "Could not create mountpoint directory '$mountpoint'"
	dev="$(get_device_by_partuuid "$partuuid")" \
		|| die "Could not resolve partition UUID '$PARTITION_UUID_LINUX'"
	mount "$dev" "$mountpoint" \
		|| die "Could not mount device '$dev'"
}

mount_root() {
	mount_by_partuuid "$PARTITION_UUID_LINUX" "$ROOT_MOUNTPOINT"
}

bind_bootstrap_dir() {
	# Use new location by default
	export GENTOO_BOOTSTRAP_DIR="$GENTOO_BOOTSTRAP_BIND"

	# Bind the bootstrap dir to a location in /tmp,
	# so it can be accessed from within the chroot
	mountpoint -q -- "$GENTOO_BOOTSTRAP_BIND" \
		&& return

	# Mount root device
	einfo "Bind mounting bootstrap directory"
	mkdir -p "$GENTOO_BOOTSTRAP_BIND" \
		|| die "Could not create mountpoint directory '$GENTOO_BOOTSTRAP_BIND'"
	mount --bind "$GENTOO_BOOTSTRAP_DIR_ORIGINAL" "$GENTOO_BOOTSTRAP_BIND" \
		|| die "Could not bind mount '$GENTOO_BOOTSTRAP_DIR_ORIGINAL' to '$GENTOO_BOOTSTRAP_BIND'"
}


install_arch() {
	mount_root
	mkdir "$ROOT_MOUNTPOINT/boot"
	mount_by_partuuid "$PARTITION_UUID_EFI" "$ROOT_MOUNTPOINT/boot"
	einfo "Installing Archlinux with base packages"
	try pacstrap "$ROOT_MOUNTPOINT" "$ADDITIONAL_PACKAGES" dhcpcd git base base-devel man-db man-pages reflector efibootmgr linux linux-firmware
	#TODO export not crucial packages into config
	einfo "generateing fstab entrys"
	try genfstab -L "$ROOT_MOUNTPOINT" >> "$ROOT_MOUNTPOINT/etc/fstab"
	#TODO own fstab generator

}


gentoo_umount() {
	if mountpoint -q -- "$ROOT_MOUNTPOINT"; then
		einfo "Unmounting root filesystem"
		umount -R -l "$ROOT_MOUNTPOINT" \
			|| die "Could not unmount filesystems"
	fi
}

init_bash() {
	source /etc/profile
	umask 0077
	export PS1='(chroot) [0;31m\u[1;31m@\h [1;34m\w [m\$ [m'
}; export -f init_bash

env_update() {
	env-update \
		|| die "Error in env-update"
	source /etc/profile \
		|| die "Could not source /etc/profile"
	umask 0077
}

mkdir_or_die() {
	mkdir -m "$1" -p "$2" \
		|| die "Could not create directory '$2'"
}

touch_or_die() {
	touch "$2" \
		|| die "Could not touch '$2'"
	chmod "$1" "$2"
}

gentoo_chroot() {
	if [[ $# -eq 0 ]]; then
		gentoo_chroot /bin/bash --init-file <(echo 'init_bash')
	fi

	[[ $EXECUTED_IN_CHROOT != true ]] \
		|| die "Already in chroot"

	gentoo_umount
	mount_root
	bind_bootstrap_dir

	# Copy resolv.conf

	einfo "Preparing chroot environment"
	install --mode=0644 /etc/resolv.conf "$ROOT_MOUNTPOINT/etc/resolv.conf" \
		|| die "Could not copy resolv.conf"

	# Mount virtual filesystems
	einfo "Mounting virtual filesystems"
	(
		mountpoint -q -- "$ROOT_MOUNTPOINT/proc" || mount -t proc /proc "$ROOT_MOUNTPOINT/proc" || exit 1
		mountpoint -q -- "$ROOT_MOUNTPOINT/tmp"  || mount --rbind /tmp  "$ROOT_MOUNTPOINT/tmp"  || exit 1
		mountpoint -q -- "$ROOT_MOUNTPOINT/sys"  || {
			mount --rbind /sys  "$ROOT_MOUNTPOINT/sys" &&
			mount --make-rslave "$ROOT_MOUNTPOINT/sys"; } || exit 1
				mountpoint -q -- "$ROOT_MOUNTPOINT/dev"  || {
					mount --rbind /dev  "$ROOT_MOUNTPOINT/dev" &&
					mount --make-rslave "$ROOT_MOUNTPOINT/dev"; } || exit 1
	) || die "Could not mount virtual filesystems"

	# Execute command
	einfo "Chrooting..."
	EXECUTED_IN_CHROOT=true \
		TMP_DIR=$TMP_DIR \
		exec chroot -- "$ROOT_MOUNTPOINT" "$GENTOO_BOOTSTRAP_DIR/scripts/main_chroot.sh" "$@" \
		|| die "Failed to chroot into '$ROOT_MOUNTPOINT'"
}

bash_configuration() {
	einfo "load bash configuration with bashcomplet"
	pacman -S bash-completion
    cp "$GENTOO_BOOTSTRAP_DIR/configfiles/bash/bash.bashrc" "/etc/bash.bashrc"
	if $CREATE_USER; then
		cp "$GENTOO_BOOTSTRAP_DIR/configfiles/bash/.bashrc" "/home/$USER_NAME/.bashrc"
	fi
	cp "$GENTOO_BOOTSTRAP_DIR/configfiles/bash/inputrc" "/etc/inputrc"
	einfo "bash configuration finished"
}

nvim_configuration() {
	einfo "load configuration for nvim"
	pacman -S python-pynvim
	cp "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/sysinit.vim" "/etc/xdg/nvim/sysinit.vim"
	cp "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/nvimrc.local" "/etc/vim/nvimrc.local"
	cp "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/nvimrc.user" "/etc/vim/nvimrc.user"
	if $CREATE_USER; then
		try "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/dein-installer.sh" "/home/$USER_NAME/.config/nvim/dein"
		cp "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/NVIM_FINISH_open_with_nvim.txt" "/home/$USER_NAME/NVIM_FINISH_open_with_nvim.txt"
	fi
	try "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/dein-installer.sh" "/root/.config/nvim/dein"
	cp "$GENTOO_BOOTSTRAP_DIR/configfiles/nvim/NVIM_FINISH_open_with_nvim.txt" "/root/NVIM_FINISH_open_with_nvim.txt"
	einfo "nvim Installation has to be finished in vim READ NVIM_FINISH_open_with_nvim.txt"
	sleep 10

}
