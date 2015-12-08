#!/bin/bash

btrfs_path='/var/shocker'
cgroups='cpu,cpuacct,memory'

shocker_check() {
  btrfs subvolume list "$btrfs_path" | grep -qw "$1"
  echo $?
  return $?
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
  [ ! -d "$btrfs_path/$1" ] && echo missing && return
  [ -d "/sys/fs/cgroup/cpuacct/$1" ] && cgdef=1 || cgdef=0
  grep -q . "/sys/fs/cgroup/cpuacct/$1/tasks" 2>/dev/null && procs=1 || procs=0
  ip netns show | grep -q "netns_$1" 2>/dev/null && netns=1 || netns=0
  ip link show | grep -q "veth0_$1" 2>/dev/null && veth=1 || veth=0

  state=crashed
  [ $((cgdef & procs & netns & veth)) -eq 1 ] && state=running
  [ $((cgdef | procs | netns | veth)) -eq 0 ] && state=stopped

  echo $state
}

shocker_execute() {
  cntid="$1"
  shift;
  cgexec -g "$cgroups:$cntid" \
    ip netns exec netns_"$cntid" \
    unshare -fmuip --mount-proc \
    chroot "$btrfs_path/$cntid" \
    /bin/sh -c "source /root/init; $*" || true
}

get_base_network () {
  . ./settings.conf 2> /dev/null
  echo "${NETWORK:-10.0.0.0/24}"
}

get_mask () {
  NETWORK="$(get_base_network)"
  # shellcheck disable=SC2001
  echo "$NETWORK" | sed 's#^.*/##g'
}

get_nhosts () {
  MASK=$(get_mask)
  echo $((2**(32-MASK)))
}

get_network () {
  addr_to_network "$(get_base_network)"
}

get_gateway () {
  NETWORK=$(get_network)
  echo $((NETWORK + 1))
}

get_bridge_dev () {
  . ./settings.conf 2> /dev/null
  echo "$BRIDGE_DEV"
}

gen_uuid() {
  fifo=$(mktemp -p /tmp -u XXXX)
  mkfifo "$fifo"
  seq -f "%010g" 2 "$1" > "$fifo" &
  find "$btrfs_path" -maxdepth 1 -type d -name 'ps_*' \
    | sed 's#^.*/ps_##' \
    | xargs printf "%010d\n" \
    | sort \
    | comm -1 -3 - "$fifo" \
    | head -1 \
    | sed 's/^0*//'
  rm -f "$fifo"
}
