# Shocker
Docker implemented in around 100 lines of shell.
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

## Prerequisites
The following packages are needed to run shocker.

* btrfs-progs
* curl
* iproute2
* iptables
* libcgroup-tools
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

## Example Usage
```
$ shocker pull centos 7
######################################################################## 100.0%
######################################################################## 100.0%
######################################################################## 100.0%
Created: img_42150

$ shocker images
IMAGE_ID        SOURCE
img_42150       centos:7

$ shocker run img_42150 cat /etc/centos-release
CentOS Linux release 7.1.1503 (Core)

$ shocker ps
CONTAINER_ID       COMMAND
ps_42045           cat /etc/centos-release

$ shocker logs ps_42045
CentOS Linux release 7.1.1503 (Core)

$ shocker rm ps_42045
Removed: ps_42045

$ shocker run img_42150 which wget
which: no wget in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin)

$ shocker run img_42150 yum install -y wget
Installing : wget-1.14-10.el7_0.1.x86_64                                  1/1
Verifying  : wget-1.14-10.el7_0.1.x86_64                                  1/1
Installed  : wget.x86_64 0:1.14-10.el7_0.1
Complete!

$ shocker ps
CONTAINER_ID       COMMAND
ps_42018           yum install -y wget
ps_42182           which wget

$ shocker commit ps_42018 img_42150
Removed: img_42150
Created: img_42150

$ shocker run img_42150 which wget
/usr/bin/wget

$ shocker run img_42150 cat /proc/1/cgroup
...
4:memory:/ps_42152
3:cpuacct,cpu:/ps_42152

$ cat /sys/fs/cgroup/cpu/ps_42152/cpu.shares
512

$ cat /sys/fs/cgroup/memory/ps_42152/memory.limit_in_bytes
512000000

$ SHOCKER_CPU_SHARE=1024 \
	SHOCKER_MEM_LIMIT=1024 \
	shocker run img_42150 cat /proc/1/cgroup
...
4:memory:/ps_42188
3:cpuacct,cpu:/ps_42188

$ cat /sys/fs/cgroup/cpu/ps_42188/cpu.shares
1024

$ cat /sys/fs/cgroup/memory/ps_42188/memory.limit_in_bytes
1024000000
```

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
$ dd if=/dev/zero of=btrfs-hdd.img bs=1G count=2
$ sudo losetup loop0 btrfs-hdd.img
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
