#!/usr/bin/env bash
set -euo pipefail

babeld=../babeld/babeld

cargo build

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root :("
   exit 1
fi

fail_string()
{
 if grep -q "$1" "$2"; then
   echo "FAILED: $1 in $2"
   exit 1
 fi
}

pass_string()
{
 if ! grep -q "$1" "$2"; then
   echo "FAILED: $1 not in $2"
   exit 1
 fi
}

stop_processes()
{
  set +eux
    for f in *.pid
    do
      kill -9 "$(cat $f)"
    done
  set -eux
}

cleanup()
{
  rm -f ./*.pid
  rm -f ./*.log
}

stop_processes
cleanup

source ./network-lab.sh << EOF
{
  "nodes": {
    "1": { "ip": "2001::1" },
    "2": { "ip": "2001::2" },
    "3": { "ip": "2001::3" }  

},
  "edges": [
     {
      "nodes": ["1", "2"],
      "->": "loss random 0%",
      "<-": "loss random 0%"
     },
     {
      "nodes": ["2", "3"],
      "->": "loss random 0%",
      "<-": "loss random 0%"
     }
  ]
}
EOF
sleep 2

ip netns exec netlab-1 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-1 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-1 ip route add 2001::2/128 dev veth-1-2 src 2001::1

ip netns exec netlab-2 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-2 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-2 ip route add 2001::1/128 dev veth-2-1 src 2001::2
ip netns exec netlab-2 ip route add 2001::3/128 dev veth-2-3 src 2001::2

ip netns exec netlab-3 sysctl -w net.ipv4.ip_forward=1
ip netns exec netlab-3 sysctl -w net.ipv6.conf.all.forwarding=1
ip netns exec netlab-3 ip route add 2001::2/128 dev veth-3-2 src 2001::3


RUST_BACKTRACE=full ip netns exec netlab-2 ./target/debug/server >server.log &
sleep 1
ip netns exec netlab-1 ./target/debug/client
RUST_BACKTRACE=full ip netns exec netlab-2 ./target/debug/server >server.log &
sleep 1
ip netns exec netlab-3 ./target/debug/client
sleep 1

ip netns exec netlab-1 $babeld -I babeld-n1.pid -d 1 -L babeld-n1.log -h 1 -P 5 -w wg0 -G 8080 &
ip netns exec netlab-2 $babeld -I babeld-n2.pid -d 1 -L babeld-n2.log -h 1 -P 10 -w wg0 wg1 -G 8080 &
ip netns exec netlab-3 $babeld -I babeld-n3.pid -d 1 -L babeld-n3.log -h 1 -P 5 -w wg0 -G 8080 &
sleep 10
ip netns exec netlab-1 ping -c 10 $(tail -n 2 server.log | head -n 1)

stop_processes
