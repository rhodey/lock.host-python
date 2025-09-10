#!/bin/sh
set -e

# net
if [[ "${PROD}" == "true" ]]; then
  ifconfig lo up
  ip route add 0.0.0.0/0 dev lo
fi

# net
iptables -A OUTPUT -t nat -p udp --dport 53 -j DNAT --to-destination 127.0.0.1:53
iptables -A OUTPUT -t nat -p tcp --dport 1:65535 ! -d 127.0.0.1 -j DNAT --to-destination 127.0.0.1:9000
iptables -t nat -A POSTROUTING -o lo -s 0.0.0.0 -j SNAT --to-source 127.0.0.1

# clock
if [[ "${PROD}" == "true" ]]; then
  cat /sys/devices/system/clocksource/clocksource0/current_clocksource
  [ "$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)" = "kvm-clock" ] || exit 1
fi

# for test
chown -f root /tmp/write || true

# start
cd /runtime
node runtime.js 8888 python -u /app/app.py 8889
