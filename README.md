**TL;DR:** Edit `scripts/config.sh` and execute `./install` in any live system.

---

# Arch installation script


This script performs a reasonably minimal installation of archlinux for an EFI system.
It does everything from the ground up, including creating partitions, initial system configuration
and optionally installing some additional software. The script only supports systemd and not OpenRC.

It will stick closely to the [Arch Wiki Installation Guide](https://wiki.archlinux.org/index.php/installation_guide)
It is based on the Install Skript from [nyronium](https://github.com/nyronium/gentoo-bootstrap)



## Overview

Here is a quick overview of what this script does:

* Does everything minus something
* Partition the device (efi, optional swap, linux root)
* Configure the base system
  - Set hostname
  - Set timezone
  - Set keymap
  - Generate and select locale
* Sorts pacman mirrors in favor of the fastest
* Install git (so you can add your portage overlays later)
* Create boot entry using efibootmgr
* Generate fstab
* Lets you set a root password

Also, optionally the following will be done:

* Install sshd with secure config
* Install ansible, create ansible user and add authorized ssh key
* Install additional packages provided in config
* Optionally creates a user
* Optionally installs yay as aur package manager

Anything else is probably out of scope for this script,
but you can obviously do anything later on when the system is booted.

What you will **NOT** get: (i.e. you will have to do it yourself)

* X11 desktop environment

Only necessary configuration is applied to provide a common baseline system.
If you need advanced features such as an initramfs or a different
partitioning scheme, you can definitely use this script but will
have to make some adjustments to it.

The main purpose of this script is to provide a universal setup
which should be suitable for most use-cases (desktop and server installations).


# Install

Installing gentoo with this script is simple.

1. Boot into the live system of your choice. As the script requires some utilities,
   I recommend using a live system where you can quickly install new software.
   Any [Arch Linux](https://www.archlinux.org/download/) live iso works fine.
2. Clone this repository
3. Edit `scripts/config.sh`, and particularily pay attention to
   the device which will be partitioned. The script will ask before partitioning,
   but better be safe than sorry.
4. Execute `./install`. The script will tell you if your live
   system is missing any required software.

## Config

The config file `scripts/config.sh` allows you to adjust some parameters of the installation.
The most important ones will probably be the device to partition, and the stage3 tarball name
to install. By default you will get the hardened nomultilib profile without systemd.

### Using existing partitions
 
If you want to use existing partitions, you will have to set `ENABLE_PARTITIONING=false`.
As the script uses uuids to refer to partitions, you will have to set the corresponding
partition uuid variables in the config (all variables beginning with `PARTITION_UUID_`).

## (Optional) sshd

The script can provide a fully configured ssh daemon with reasonably good security settings.
It will by default run on port `2222`, only allow ed25519 keys, restrict the key exchange
algorithms, disable any password based authentication, and only allow specifically mentioned
users to use ssh service (none by default).

To add a user to the list of allowed users, append `AllowUsers myuser` to `/etc/ssh/sshd_config`.
I recommend to create a separate group for all ssh users (like `sshusers`) and
to use `AllowGroups sshusers`. You should adjust this to your preferences when
the system is installed.

## (Optional) Ansible

This script can install ansible, create a system user for ansible and add an ssh key of
you choice to the `.authorized_keys` file. This allows you to directly use ansible when
the new system is up to configure the rest of the system.

## (Optional) Additional packages

You can enter any amount of additional packages to be installed on the target system.
These will simply be passed to pacstrap and are imediatly avalable.
errors installing this pacages can lead to potantial failure of the script
packages only avalabe in aur must be installed later

## Troubleshooting

The script checks every command for success, so if anything fails during installation,
you will be given a proper message of what went wrong. Inside the chroot,
most commands will be executed in´ some kind of try loop, and allow you to
fix problems interactively with a shell, to retry, or to skip the command.

# Recommendations

There are some things that you probably want to do after installing the base system,
or should consider:

* Edit `/etc/ssh/sshd_config`, change the port if you want and create a `sshusers` group.


# References

* [Initialy forked from nyronium gentoo-bootstrap](https://github.com/nyronium/gentoo-bootstrap)
* [Arch Wiki Installation Guide](https://wiki.archlinux.org/index.php/installation_guide)
