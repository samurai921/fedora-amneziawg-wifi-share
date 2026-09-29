# Диагностика раздачи VPN

Начинайте с чтения состояния. Не удаляйте профиль Home-WiFi,
не очищайте firewall и не перезапускайте Docker для проверки гипотез.
Не используйте `nmcli --show-secrets` и не публикуйте VPN-конфигурацию.

## 1. Проверить Wi-Fi и профиль

```bash
nmcli device status
nmcli radio all
rfkill list
nmcli -f connection.id,connection.interface-name,connection.autoconnect,802-11-wireless.ssid,802-11-wireless.mode,ipv4.method connection show Home-WiFi
nmcli device show wlp8s0f3u4u4
ip -br address
```

Ожидаются активный Home-WiFi на нужном адаптере, режим `ap`,
метод IPv4 `shared` и адрес `10.42.0.1/24`. Для Wireless LAN блокировки
`Soft blocked` и `Hard blocked` должны отсутствовать. Блокировка Bluetooth
не означает блокировку Wi-Fi.

Если доступна утилита `iw`, проверьте реальный режим и подключённых клиентов:

```bash
iw dev wlp8s0f3u4u4 info
iw dev wlp8s0f3u4u4 station dump
```

Ожидается `type AP`. Запись клиента с `authorized: yes` подтверждает
подключение к точке доступа. Название SSID с `5G` само по себе не означает
работу на частоте 5 ГГц: фактический канал показывает `iw`.

## 2. Проверить журналы

```bash
journalctl -b -u NetworkManager --no-pager \
  -g 'wlp8s0f3u4u4|Home-WiFi|amn0|tun2|dnsmasq' -n 120
journalctl -b -k --no-pager \
  -g 'wlp8s0f3u4u4|rtw|rtl|cfg80211' -n 60
```

`DHCPACK` с адресом из `10.42.0.0/24` подтверждает выдачу адреса клиенту,
но не наличие интернета. Журналы могут содержать имена и адреса устройств;
перед публикацией удалите ненужные персональные данные.

## 3. Проверить VPN и маршруты

```bash
ip -br address
ip -4 rule show
ip -4 route get 1.1.1.1
ip -4 route get 1.1.1.1 from 10.42.0.2 iif wlp8s0f3u4u4
sysctl net.ipv4.ip_forward
```

Подставьте адрес клиента вместо примера `10.42.0.2`.
Проверьте, что в маршруте указан нужный VPN-интерфейс и пересылка равна `1`.
Отсутствие `amn0` при работающем `tun2` не означает поломку Wi-Fi.

При наличии `curl` и `dig` можно отдельно проверить интернет Fedora и DNS
точки доступа:

```bash
curl -4 --noproxy '*' --connect-timeout 5 --max-time 10 -I https://example.com
dig +time=2 +tries=1 @10.42.0.1 example.com A
```

Успешные запросы с Fedora не доказывают работу пересылки от клиента.

## 4. Проверить службу и действующие правила

```bash
systemctl status lg-vpn-share.service --no-pager
systemctl cat lg-vpn-share.service
journalctl -b -u lg-vpn-share.service --no-pager -n 50
sudo iptables -S DOCKER-USER
sudo iptables -nvL DOCKER-USER --line-numbers
sudo iptables -nvL FORWARD --line-numbers
sudo nft list table ip nm-shared-wlp8s0f3u4u4
docker ps --format '{{.Names}}\t{{.Status}}'
```

Последняя таблица nftables существует в проверенной конфигурации;
на другой версии NetworkManager имя таблицы или backend могут отличаться.
Отсутствие NAT в выводе `iptables -t nat` само по себе не доказывает его
отсутствие в nftables.

Сопоставьте выходной интерфейс из маршрута с правилами `DOCKER-USER`.
Если разрешения есть только для `amn0`, они не пропустят пакеты через `tun2`.
При политике `FORWARD DROP` и отсутствии другого разрешения эти пакеты
будут отброшены, даже если NetworkManager настроил DHCP и NAT.

## Подтверждённый сбой 29.09.2026

- Home-WiFi оставался активным, телефон получал адрес по DHCP.
- Wi-Fi не был заблокирован, `ip_forward` был равен `1`.
- В журнале `amn0` исчез в 21:29 по московскому времени; текущий VPN
  использовал `tun2`, через него же шёл маршрут клиента.
- Служба отображалась как `active (exited)`, но установленный скрипт
  содержал только разрешения для `amn0`; оба их счётчика были нулевыми.
- В `FORWARD` действовала политика `DROP`.

После добавления пары узких правил для `tun2` счётчики стали расти в обоих
направлениях, пользователь подтвердил работу интернета. Эти же правила
добавлены в установленный скрипт автозапуска и скрипт репозитория.
Профиль Home-WiFi, маршруты, правила контейнеров и общая политика firewall
не менялись. Docker и семь контейнеров не перезапускались.

## Действия только после установления причины

- Если Wi-Fi программно выключен — включите `sudo nmcli radio wifi on`.
- Если профиль существует, но не активен — после проверки причины запустите
  `sudo nmcli connection up Home-WiFi ifname wlp8s0f3u4u4`.
- Если нужный VPN отключён — подключите его в AmneziaVPN и повторите проверку
  маршрута. Не подменяйте интерфейс произвольным выходом в интернет.
- Если маршрут идёт через `tun2`, а установлен старый скрипт только для
  `amn0` — обновите скрипт по README и примените его.
- Если разрешения пропали после изменения firewall — убедитесь, что
  `DOCKER-USER` существует, и выполните:

```bash
sudo systemctl restart lg-vpn-share.service
sudo iptables -nvL DOCKER-USER --line-numbers
```

Повторный запуск добавляет отсутствующие правила без дубликатов.
Не используйте `iptables -F`, `nft flush ruleset` или общий `FORWARD ACCEPT`
как способ исправления этой проблемы.

Если правила и маршруты верны, но интернета нет, продолжайте проверку DNS,
самого VPN и других цепочек firewall. Не считайте `active (exited)`
доказательством работоспособности всей схемы.
