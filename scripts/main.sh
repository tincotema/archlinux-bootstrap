################################################
# Initialize script environment

# Find the directory this script is stored in. (from: http://stackoverflow.com/questions/59895)
get_source_dir() {
	local source="${BASH_SOURCE[0]}"
	while [[ -h "${source}" ]]
	do
		local tmp="$(cd -P "$(dirname "${source}")" && pwd)"
		source="$(readlink "${source}")"
		[[ "${source}" != /* ]] && source="${tmp}/${source}"
	done

	echo -n "$(realpath "$(dirname "${source}")")"
}

export GENTOO_BOOTSTRAP_DIR_ORIGINAL="$(dirname "$(get_source_dir)")"
export GENTOO_BOOTSTRAP_DIR="$GENTOO_BOOTSTRAP_DIR_ORIGINAL"
export GENTOO_BOOTSTRAP_SCRIPT_ACTIVE=true
export GENTOO_BOOTSTRAP_SCRIPT_PID=$$

umask 0077

source "$GENTOO_BOOTSTRAP_DIR/scripts/utils.sh"
source "$GENTOO_BOOTSTRAP_DIR/scripts/config.sh"
source "$GENTOO_BOOTSTRAP_DIR/scripts/functions.sh"

mkdir -p "$TMP_DIR"
[[ $EUID == 0 ]] \
	|| die "Must be root"


################################################
# Functions

install_with_pacstrap() {
	[[ $# == 0 ]] || die "Too many arguments"

	prepare_installation_environment
	partition_device
	format_partitions
	install_arch
}

main_install_gentoo_in_chroot() {
	[[ $# == 0 ]] || die "Too many arguments"

	# Lock the root password, making the account unaccessible for the
	# period of installation, except by chrooting
	einfo "Locking root account"
	passwd -l root \
		|| die "Could not change root password"

	# Mount efi partition
	einfo "Mounting efi"
	mount_by_partuuid "$PARTITION_UUID_EFI" "/boot"

	# Sync pacman
	einfo "Syncing pacman"
	try pacman -Sy

	# Set hostname
	einfo "Selecting hostname"
	sed -i "/hostname=/c\\hostname=\"$HOSTNAME\"" /etc/conf.d/hostname \
		|| die "Could not sed replace in /etc/conf.d/hostname"

	# Set timezone
	einfo "Selecting timezone"
	echo "$TIMEZONE" > /etc/timezone \
		|| die "Could not write /etc/timezone"
	try hwclock --systohc

	# Set locale
	einfo "Selecting locale"
	echo "$LOCALES" > /etc/locale.gen \
		|| die "Could not write /etc/locale.gen"
	locale-gen \
		|| die "Could not generate locales"
	try locale-gen
	echo "$LOCALELANG" > /etc/locale.conf \
		|| die "Could not write /etc/locale.conf"

	# Set keymap
	einfo "Selecting keymap"
	sed -i "/keymap=/c\\$KEYMAP" /etc/vconsole.conf \
		|| die "Could not sed replace in /etc/vconsole.conf"


	# Install additional packages, if any.
	if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
		einfo "Installing additional packages"
		emerge --autounmask-continue=y -- $ADDITIONAL_PACKAGES
	fi
	#Create boot entry
	einfo "Creating efi boot entry"
	local linuxdev
	linuxdev="$(get_device_by_partuuid "$PARTITION_UUID_LINUX")" \
		|| die "Could not resolve partition UUID '$PARTITION_UUID_LINUX'"
	local efidev
	efidev="$(get_device_by_partuuid "$PARTITION_UUID_EFI")" \
		|| die "Could not resolve partition UUID '$PARTITION_UUID_EFI'"
	local efipartnum="${efidev: -1}"
	try efibootmgr --verbose --create --disk "$PARTITION_DEVICE" --part "$efipartnum" --label "arch" --loader '\vmlinuz-linux' --unicode "root=$linuxdev initrd=\\initramfs-linux.img"

	#create_ansible_user
	#generate_fresh keys to become mgmnt ansible user
	#install_ansible

	if ask "Do you want to assign a root password now?"; then
		passwd root
		einfo "Root password assigned"
	else
		passwd -d root
		ewarn "Root password cleared, set one as soon as possible!"
	fi

	einfo "Archlinux installation complete."
	einfo "To chroot into the new system, simply execute the provided 'chroot' wrapper."
	einfo "Otherwise, you may now reboot your system."
}

main_install() {
	[[ $# == 0 ]] || die "Too many arguments"

	gentoo_umount
	install_with_pacstrap
	gentoo_chroot "$GENTOO_BOOTSTRAP_BIND/scripts/main.sh" install_gentoo_in_chroot
}

main_chroot() {
	gentoo_chroot "$@"
}

main_umount() {
	gentoo_umount
}


################################################
# Main dispatch

# Instantly kill when pressing ctrl-c
trap 'kill "$GENTOO_BOOTSTRAP_SCRIPT_PID"' INT

SCRIPT_ALIAS="$(basename "$0")"
if [[ "$SCRIPT_ALIAS" == "main.sh" ]]; then
	SCRIPT_ALIAS="$1"
	shift
fi

case "$SCRIPT_ALIAS" in
	"chroot") main_chroot "$@" ;;
	"install") main_install "$@" ;;
	"install_gentoo_in_chroot") main_install_gentoo_in_chroot "$@" ;;
	"umount") main_umount "$@" ;;
	*) die "Invalid alias '$SCRIPT_ALIAS' was used to execute this script" ;;
esac
