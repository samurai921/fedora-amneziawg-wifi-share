#!/bin/bash

# Правила вставляются в обратном порядке: каждое идёт в начало цепочки,
# поэтому итоговый порядок — сначала Wi-Fi -> AmneziaWG, затем ответы.

# Разрешаем ответы AmneziaWG -> Wi-Fi
iptables -C DOCKER-USER \
  -i amn0 \
  -o wlp8s0f3u4u4 \
  -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT 2>/dev/null || \
iptables -I DOCKER-USER 1 \
  -i amn0 \
  -o wlp8s0f3u4u4 \
  -d 10.42.0.0/24 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

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
