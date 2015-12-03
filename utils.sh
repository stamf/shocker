#!/bin/bash

btrfs_path='/var/shocker'

shocker_check() {
  btrfs subvolume list "$btrfs_path" | grep -qw "$1" && echo 0 || echo 1
}

ip_to_int() { #Transform ipv4 address into int
  local IFS='[./]'
  set -- "$1"
  echo $(($1 * 256**3 + $2 * 256**2 + $3 * 256**1 + $4))
}

int_to_ip() { #Transform int into ipv4 address
  printf "%d.%d.%d.%d" \
    $((($1 & 256**4-1) / 256**3)) \
    $((($1 & 256**3-1) / 256**2)) \
    $((($1 & 256**2-1) / 256**1)) \
    $(( $1 & 256**1-1))
}

int_to_mac() { #Transform int into mac address
  printf "02:42:%02x:%02x:%02x:%02x" \
    $((($1 & 256**4-1) / 256**3)) \
    $((($1 & 256**3-1) / 256**2)) \
    $((($1 & 256**2-1) / 256**1)) \
    $(( $1 & 256**1-1))
}

addr_to_network() { #Transforms ip/mask into an int representing the network
  local IFS=/
  set -- "$1"
  mask=$(((2**$2-1) * 2**(32-$2)))
  addr=$(ip_to_int "$1")
  echo $((addr & mask))
}

addr_to_hostid() { #Transforms ip/mask into an int representing the host
  local IFS=/
  set -- "$1"
  mask=$((2**(32-$2)-1))
  addr=$(ip_to_int "$1")
  echo $((addr & mask))
}
