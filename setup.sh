#!/bin/sh

if [ $# -ne 1 ]; then
    echo "$0 <ethernet-device>" >&2
    exit 1
fi

if [ "$(whoami)" != "root" ]; then
    echo "Must be root" >&2
    exit 2
fi

if ip link list "$1" >/dev/null 2>&1; then
    :
else
    echo "$0 <ETHERNET-DEVICE>" >&2
fi

if mount | grep -q /dev/sda2; then :; else
    mount /dev/sda2 /var/shocker
fi

if ip link list bridge0 >/dev/null 2>&1; then
    ip link del bridge0
fi

ip link add bridge0 type bridge
ip addr add 11.0.0.1/24 dev bridge0
ip link set bridge0 up

iptables -t nat -F
iptables -t nat -A POSTROUTING -o bridge0 -j SNAT --to 11.0.0.1
iptables -t nat -A POSTROUTING -o "$1" -j MASQUERADE
