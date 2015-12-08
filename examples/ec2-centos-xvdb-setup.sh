#!/bin/sh

# Create and mount a filesystem on CentOS with an
# xvdb shared volume as the btrfs filesystem.

# install dependencies
sudo yum install btrfs-progs

# format xvdb into btrfs filesystem
sudo mkfs -t btrfs /dev/xvdb

# create btrfs mount node
sudo mkdir -p '/var/shocker'

# mount btrfs filesystem onto mount node
sudo mount '/dev/xvdb' '/var/shocker'
