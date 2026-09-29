#!/bin/bash
set -e

# Разрешаем Wi-Fi -> AmneziaWG
iptables -C DOCKER-USER \
  -i wlp8s0f3u4u4 \
  -o amn0 \
  -s 10.42.0.0/24 \
  -j ACCEPT 2>/dev/null || \
iptables -I DOCKER-USER 1 \
  -i wlp8s0f3u4u4 \
  -o amn0 \
  -s 10.42.0.0/24 \
  -j ACCEPT

# Разрешаем ответы AmneziaWG -> Wi-Fi
iptables -C DOCKER-USER \
  -i amn0 \
  -o wlp8s0f3u4u4 \
  -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT 2>/dev/null || \
iptables -I DOCKER-USER 2 \
  -i amn0 \
  -o wlp8s0f3u4u4 \
  -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

# Раздача текущего VPN Amnezia через tun2.
# Только подсеть Wi-Fi; ответы допускаются для установленных соединений.
iptables -w 5 -C DOCKER-USER \
  -i wlp8s0f3u4u4 -o tun2 -s 10.42.0.0/24 -j ACCEPT 2>/dev/null || \
iptables -w 5 -I DOCKER-USER 1 \
  -i wlp8s0f3u4u4 -o tun2 -s 10.42.0.0/24 -j ACCEPT

iptables -w 5 -C DOCKER-USER \
  -i tun2 -o wlp8s0f3u4u4 -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -w 5 -I DOCKER-USER 2 \
  -i tun2 -o wlp8s0f3u4u4 -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
