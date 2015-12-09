#!/bin/sh

btrfs_path='/var/shocker'
cgroups='cpu,cpuacct,memory'
dirname=$(dirname "$(readlink -f "$0")")

shocker_exists() {
  btrfs subvolume list "$btrfs_path" | grep -qw "$1"
  return $?
}

shocker_running() {
  state=$(get_state "$1")
  test "$state" = "running"
  return $?
}

ip_to_int() { #Transform ipv4 address into int
  # shellcheck disable=SC2001
  eval set -- "$(echo "$1" | sed 's|[./]| |g')"
  echo "$1 256 3 ^ * $2 256 2 ^ * + $3 256 * + $4 + p" | dc
}

int_to_ip() { #Transform int into ipv4 address
  echo "
    $1 256 3 ^ / p
    $1 256 2 ^ / 256 % p
    $1 256 1 ^ / 256 % p
    $1 256 % p" \
      | dc \
      | xargs printf "%d.%d.%d.%d"
}

int_to_mac() { #Transform int into mac address
  echo "
    $1 256 3 ^ / p
    $1 256 2 ^ / 256 % p
    $1 256 1 ^ / 256 % p
    $1 256 % p" \
      | dc \
      | xargs printf "02:42:%02x:%02x:%02x:%02x"
}

addr_to_network() { #Transforms ip/mask into an int representing the network
  # shellcheck disable=SC2001
  eval set -- "$(echo "$1" | sed 's|/| |')"

  echo "$1" \
      | sed '
          # replace dots with spaces
          s/\./ /g;
          # append "p" to contiguous numbers
          s/\([0-9]\+\)/\1p/g;
          # prepend string with "2o "
          s/^/2o /' \
      | dc \
      | sed '
          # prepend numbers with 7 zeroes
          s/^/0000000/;
          # take last 8 digits of number (zero padded)
          s/.*\(.\{8\}\)$/\1/' \
      | sed '
          # collapse lines into single line, separated by nothing
          :a;
              N;s/\n//g;
          ta' \
      | sed "
          # take first MASK digits from string, rpad with zeroes
          s/\(.\{$2\}\).*/\100000000000000000000000000000000/;
          # take first 32 digits from string, prepend with '2i ', append 'p'
          s/\(.\{32\}\).*/2i \1p/" \
      | dc
}

get_state() {
  shocker_exists "$1"
  [ "$?" -ne 0 ] && printf "Container '%s' does not exist" "$1" >&2 && exit 1
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
  #shellcheck disable=SC1090
  . "$dirname"/settings.conf 2> /dev/null
  echo "${NETWORK:-10.0.0.0/24}"
}

get_mask () {
  NETWORK="$(get_base_network)"
  echo "$NETWORK" | sed 's#^.*/##g'
}

get_nhosts () {
  MASK=$(get_mask)
  echo "2 32 $MASK - ^ p" | dc
}

get_network () {
  addr_to_network "$(get_base_network)"
}

get_gateway () {
  NETWORK=$(get_network)
  echo "1 $NETWORK + p" | dc
}

get_bridge_dev () {
  #shellcheck disable=SC1090
  . "$dirname"/settings.conf 2> /dev/null
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
