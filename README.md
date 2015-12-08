# Shocker
Docker implemented in shell. Forked from
[bocker](https://github.com/p8952/bocker).

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Example Usage](#example-usage)
- [FAQ](#faq)
- [License](#license)

## Features
- process isolation using `cgroups`, `iptables`, `chroot` and `namespaces(7)`
- advanced control over network with port forwarding
- strong focus on usability
- transparent codebase written in modern POSIX shell

## Usage
```txt
  Usage: shocker [options] <command>

  commit, cleanup, exec, export, images,
  init, kill, logs, name, ps, pull, rm,
  route, run, spawn, stop

  Options:
    -h, --help     output usage information
    -v, --version  output version information

  Examples:
    $ shocker pull -h              # output usage for the pull command
    $ shocker pull alpine latest   # fetch the latest alpine linux image
    $ shocker images               # list local images
    $ shocker run img_1235 ash     # start an ash shell from an image
```

## Prerequisites
The following packages are needed to run shocker.

* btrfs-progs
* curl
* iproute2
* iptables
* libcgroup-tools (cgroup-tools on Debian / Ubuntu)
* util-linux >= 2.25.2
* coreutils >= 7.5

Because most distributions do not ship a new enough version of util-linux you
will probably need to grab the sources from
[here](https://www.kernel.org/pub/linux/utils/util-linux/v2.25/) and compile it
yourself.

Additionally your system will need to be configured with the following:

* A btrfs filesystem mounted under `/var/shocker`
* A network bridge called `bridge0` and an IP of 10.0.0.1/24
* IP forwarding enabled in `/proc/sys/net/ipv4/ip_forward`
* A firewall routing traffic from `bridge0` to a physical interface.

Even if you meet the above prerequisites you probably still want to **run
shocker in a virtual machine**. Shocker runs as root and among other things
needs to make changes to your network interfaces, routing table, and firewall
rules.

## FAQ
### Error: btrfs: command not found
This means `btrfs` is not available on your machine. Luckily many package
managers offer a way to install this in a single command:
- `Debian/Ubuntu`: `sudo apt-get install btrfs-tools`

### Error: x is not a btrfs filesystem
That means we don't have a `btrfs` filesystem mounted, so let's create one!
From a file! Because that's easier than doing partitions!
```sh
# create a new filesystem from an empty file
# skip this step if mounting an actual device
$ dd if=/dev/zero of=btrfs-hdd.img bs=1G count=2
$ sudo losetup loop0 btrfs-hdd.img

# mount the filesystem
$ sudo mkfs.btrfs /dev/loop0

# create `/var/shocker` if it does not exist
$ [ -d '/var/shocker' ] || sudo mkdir -p '/var/shocker'

# open file as block device and mount
$ sudo mount '/dev/loop0' '/var/shocker'
$ sudo btrfs filesystem show '/var/shocker'
```

### Error: /tmp does not exist
Not every distro adheres to the Linux
[Filesystem Hierarchy Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard),
but no need to sweat about it, we can create our own:
```sh
$ sudo mkdir /tmp
$ sudo chmod 1777 /tmp   # open to everyone + set sticky bit
```

## License
GPL-3
