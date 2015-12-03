#!/bin/bash

btrfs_path='/var/shocker'

shocker_check() {
  btrfs subvolume list "$btrfs_path" | grep -qw "$1" && echo 0 || echo 1
}

ip_to_int() { #Transform ipv4 address into int
  # shellcheck disable=SC2001
  eval set -- "$(echo "$1" | sed 's|[./]| |g')"
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
  # shellcheck disable=SC2001
  eval set -- "$(echo "$1" | sed 's|/| |')"
  mask=$(((2**$2-1) * 2**(32-$2)))
  addr=$(ip_to_int "$1")
  echo $((addr & mask))
}

addr_to_hostid() { #Transforms ip/mask into an int representing the host
  # shellcheck disable=SC2001
  eval set -- "$(echo "$1" | sed 's|/| |')"
  mask=$((2**(32-$2)-1))
  addr=$(ip_to_int "$1")
  echo $((addr & mask))
}

get_state() {
  [[ ! -d "$btrfs_path/$1" ]] && echo missing && return
  [[ -d "/sys/fs/cgroup/cpuacct/$1" ]] && cgdef=1 || cgdef=0
  grep -q . "/sys/fs/cgroup/cpuacct/$1/tasks" 2>/dev/null && procs=1 || procs=0
  ip netns show | grep -q "netns_$1" 2>/dev/null && netns=1 || netns=0
  ip link show | grep -q "veth0_$1" 2>/dev/null && veth=1 || veth=0

  state=crashed
  [[ $((cgdef & procs & netns & veth)) -eq 1 ]] && state=running
  [[ $((cgdef | procs | netns | veth)) -eq 0 ]] && state=stopped

  echo $state
}
