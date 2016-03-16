# Shocker
Docker implemented in shell. Forked from
[bocker](https://github.com/p8952/bocker).

- [Features](#features)
- [Usage](#usage)
- [Prerequisites](#prerequisites)
- [FAQ](#faq)
- [Installation](#installation)
- [License](#license)

## Features
- process isolation using `cgroups`, `iptables`, `chroot` and `namespaces(7)`
- advanced control over network with port forwarding
- strong focus on usability
- transparent codebase written in modern POSIX shell

## Usage
```txt
  Usage: shocker [options] <command>

  Commands:
    list           # list containers
    start          # start a container
    change         # modify a container
    stop           # stop a container
    remove         # remove a container
    image list     # list images
    image pull     # fetch a remote image
    image create   # create an image
    image change   # modify an image
    image remove   # remove an image

  Options:
    -h, --help     output usage information
    -v, --version  output version information

  Examples:
    $ shocker image pull -h              # output usage for the pull command
    $ shocker image pull alpine@latest   # fetch alpine linux from docker
    $ shocker image list                 # list local images
    $ shocker start img_1235 ash         # start an ash shell from an image
    $ shocker change img_1235 -n beep    # rename a container
    $ shocker change beep -m 500m        # change a container's memory limit
    $ shocker list                       # list containers
    $ shocker stop beep                  # stop a running container
    $ shocker remove beep                # remove a stopped container
    $ shocker image remove img_1235      # remove a local image
```

## Prerequisites
The following packages are needed to run shocker.

* btrfs-progs (btrfs-tools on Ubuntu)
* curl
* iproute2
* iptables
* libcgroup-tools (cgroup-tools on Debian / cgroup-bin on Ubuntu)
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

### Error: argument "x" is wrong: Device does not exist
This means that a network device is not found. To enable it run `shocker route
<devicename>` to setup `iptables` rules and link the device.

### Error: libcgroup initialization failed: Cgroup is not mounted
This means cgroups are not yet mounted on your system. Use `cgconfig` to start
them up (example below uses System V init):
```sh
$ sudo service cgconfig start
```

## Installation
```sh
$ npm install -g shocker
```

## License
GPL-3
