# Arch installation script

**TL;DR:** Installs Archlinux on a new system, suited for both servers and desktops.
Optionally prepares ansible for automatic system configuration.
See [Install](#Install) for usage instructions.

---

This script will install a minimal EFI bootable arch system without an X-server.
It will stick closely to the [Arch Wiki Installation Guide](https://wiki.archlinux.org/index.php/installation_guide)
It is based on the Install Skript from [nyronium](https://github.com/nyronium/gentoo-bootstrap)

What you will get:

* bootable Archlinux with a Initramfs
* Preconfigured sshd
* efibootmgr configured

* Additional packages of your choice (only trivial installations without use flag changes)

What you will **NOT** get: (i.e. you will have to do it yourself)

* X11 desktop environment
* A user for yourself (except `root` obviously)
* Any form of RAID
* A specialized kernel, see [Kernel](#Kernel) for details on how to get one.

Only necessary configuration is applied to provide a common baseline system.
If you need advanced features such as an initramfs or a different
partitioning scheme, you can definitely use this script but will
have to make some adjustments to it.

The main purpose of this script is to provide a universal setup
which should be suitable for most use-cases (desktop and server installations).

#### Overview of executed tasks

* Check live system
* Sync time
* Partition disks
* Format partitions
* Install archlinux with pacstrap
* Chroot into new system
* Update pacman
* ... TODO MISSING!

#### GPT

The script will create GPT partition tables. If your system cannot use GPT,
this script is not suited for it.

#### EFI

It is assumed that your system can (and will) be booted via EFI.
This is not a strict requirement, but othewise you will be responsible
to make the system bootable.

This probably involves the following steps:

* Change partition type of `efi` partition to `ef02` (BIOS boot partition)
* Change partition name and filesystem name to `boot`
* Install and configure syslinux

Maybe there will be a convenience script for this at some point.
No promises though.

# Install
execude install
execude umount


# References

* [Initialy forked from nyronium gentoo-bootstrap](https://github.com/nyronium/gentoo-bootstrap)
* [Arch Wiki Installation Guide](https://wiki.archlinux.org/index.php/installation_guide)
