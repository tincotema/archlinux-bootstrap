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
	mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	einfo "Mounting efi"
	mount_by_partuuid "$PARTITION_UUID_EFI" "/boot"

	# Sync pacman
	einfo "Syncing pacman"
	try pacman -Sy
	reflector --verbose --latest 100 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

	# Set hostname
	einfo "Selecting hostname"
	touch_or_die 644 /etc/hostname
	echo "$HOSTNAME" > /etc/hostname \
		|| die "Could not sed replace in /etc/hostname"

	# Set timezone
	einfo "Selecting timezone"
	ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime \
		|| die "Could not write /etc/localtime"
	hwclock --systohc \
		|| die "Could not generate /etc/adjtime"

	# Set locale
	einfo "Selecting locale"
	echo "$LOCALES" > /etc/locale.gen \
		|| die "Could not write /etc/locale.gen"
	locale-gen \
		|| die "Could not generate locales"
	touch_or_die 644 /etc/locale.conf
	echo "$LOCALELANG" > /etc/locale.conf \
		|| die "Could not write /etc/locale.conf"

	# Set keymap
	einfo "Selecting keymap"
	touch_or_die 644 /etc/vconsole.conf
	echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf \
		|| die "Could not sed replace in /etc/vconsole.conf"


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


	if [[ "$CREATE_USER" == true ]]; then
		useradd -m -g users -G "$USER_GROUP_ADDITIONAL" "$USER_NAME"
		einfo "User $USER_NAME with additional Groups $USER_GROOP_ADDITIONAL added"
		passwd "$USER_NAME"
	else
		ewarn "No User added"
	fi

    # install bash config
    bash_configuration

	#instll nvim config
	nvim_configuration


    if [[ "$INSTALL_SSHD_FOR_USER" == true || "$INSTALL_ANSIBLE" == true ]]; then
		einfo "enable SSHD"
		cp "$GENTOO_BOOTSTRAP_DIR/configfiles/ssh/sshd_config" "/etc/ssh/sshd_config"
		systemctl enable sshd.service
		if [[ "$INSTALL_SSHD_USER" == true ]];then
			einfo "Adding authorized key for $USER_NAME"
			mkdir_or_die 0700 "/home/$USER_NAME/.ssh"
			echo "$USER_SSH_AUTHORIZED_KEY" >> "/home/$USER_NAME/.ssh/authorized_keys" \
				|| die "Could not add ssh key to authorized_keys"

			einfo "Allowing $USER_NAME for ssh"
			echo "ALLowUsers $USER_NAME" >> "/etc/ssh/sshdconfig" \
				|| die "Could not append to /etc/ssh/sshd_config"
		fi
	fi


	# create_ansible_user
	# and install_ansible
    if [[ "$INSTALL_ANSIBLE" == true ]]; then
		einfo "Installing Ansible"
		pacman --noconfirm -S ansible
		useradd -r -d "$ANSIBLE_HOME" -s /bin/bash ansible
		einfo "Adding authorized key for Ansible"
		mkdir_or_die 0700 "$ANSIBLE_HOME"
		mkdir_or_die 0700 "$ANSIBLE_HOME/.ssh"
		echo "$ANSIBLE_SSH_AUTHORIZED_KEYS" >> "$ANSIBLE_HOME/.ssh/authorized_keys" \
			|| die "Could not add ssh key to authorized_keys"

		einfo "Allowing ansible for ssh"
		echo "ALLowUsers ansible" >> "/etc/ssh/sshdconfig" \
			|| die "Could not append to /etc/ssh/sshd_config"
	fi

	if [[ "$INSTALL_YAY" == true && ( "$CREATE_USER" == true || "$INSTALL_ANSIBLE" == true ) ]]; then
		einfo "installing YAY"
		if [[ "$CREATE_USER" == true ]]; then
			einfo "installing with user $USER_NAME"
			cd "$TMP_DIR" \
				|| die "Could not cd in TMP_DIR"
			git clone https://aur.archlinux.org/yay.git
			cd yay \
				|| die "Could not cd in yay"
			sudo -u "USER_NAME" makepkg -si
		elif [[ "$INSTALL_ANSIBLE" == true ]]; then
			einfo "installing wiht user ansible"
			cd "$TMP_DIR" \
				|| die "Could not cd in TMP_DIR"
			git clone https://aur.archlinux.org/yay.git
			cd yay \
				|| die "Could not cd in yay"
			sudo -u ansible makepkg -si
		fi
	fi





	#ask for root password
	if ask "Do you want to assign a root password now?"; then
		passwd root
		einfo "Root password assigned"
	else
		passwd -d root
		ewarn "Root password cleared, set one as soon as possible!"
	fi

	# making shure everything in /home/user is onwed by user
	if [[ "$CREATE_USER" == true ]]; then
		chown -R "$USER_NAME:users" "/home/$USER_NAME" \
			|| die "Could not change onwership of $USER_NAME home"
	fi

	if [[ "$INSTALL_ANSIBLE" == true ]]; then
		chown -R ansible: "$ANSIBLE_HOME" \
			|| die "Could not change onwership of ansible home"
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
