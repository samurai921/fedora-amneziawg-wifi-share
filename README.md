# Fedora + AmneziaWG 2: раздача VPN через Wi-Fi

Раздача интернет-соединения через AmneziaWG 2 с компьютера Fedora
на LG webOS, телефон и другие устройства через Wi-Fi-точку доступа.

## Схема

```text
Интернет
   |
Ethernet: enp4s0
   |
Fedora
   |-- AmneziaVPN / AmneziaWG 2: amn0
   |
Wi-Fi: wlp8s0f3u4u4
   |
NetworkManager hotspot: Home-WiFi
   |
LG webOS / телефон
```

## Параметры проверенной конфигурации

| Параметр | Значение |
|---|---|
| ОС | Fedora |
| Основной интернет | Ethernet `enp4s0` |
| VPN | AmneziaWG 2 |
| VPN-интерфейс | `amn0` |
| Wi-Fi-интерфейс | `wlp8s0f3u4u4` |
| Профиль точки доступа | `Home-WiFi` |
| Режим Wi-Fi | `ap` |
| Адрес Fedora в Wi-Fi | `10.42.0.1/24` |
| Подсеть клиентов | `10.42.0.0/24` |
| Фильтрация | iptables, цепочка `DOCKER-USER` |

Названия интерфейсов могут отличаться на другом компьютере.

## Предварительные требования

- Рабочее подключение AmneziaVPN с интерфейсом `amn0`.
- Интернет на Fedora через Ethernet.
- Wi-Fi-адаптер с поддержкой режима AP.
- NetworkManager.
- Docker с существующей цепочкой `DOCKER-USER`.
- Права sudo.

## 1. Проверить интерфейсы

```bash
nmcli device status
ip -br address
ip route get 1.1.1.1
```

При активном VPN маршрут к `1.1.1.1` должен использовать `amn0`.

## 2. Настроить точку доступа

В этой конфигурации профиль `Home-WiFi` уже был создан через
NetworkManager в режиме AP с IPv4 method `shared`.

Проверка:

```bash
nmcli -f \
connection.id,connection.type,connection.interface-name,802-11-wireless.mode,ipv4.method \
connection show Home-WiFi
```

Ожидаемые значения:

- `connection.type`: `802-11-wireless`
- `connection.interface-name`: `wlp8s0f3u4u4`
- `802-11-wireless.mode`: `ap`
- `ipv4.method`: `shared`

Включить автоподключение:

```bash
sudo nmcli connection modify Home-WiFi connection.autoconnect yes
```

Запустить точку доступа:

```bash
sudo nmcli connection up Home-WiFi ifname wlp8s0f3u4u4
```

Если появляется `No suitable device found`, проверить:

```bash
nmcli device status
nmcli radio wifi
rfkill list
```

## 3. Включить пересылку IPv4

Проверить:

```bash
sysctl net.ipv4.ip_forward
```

Для работы пересылки необходимо значение `1`.

NetworkManager в режиме IPv4 `shared` обычно настраивает
пересылку и NAT для подсети точки доступа.

## 4. Установить правила firewall

В данной системе Docker использует цепочку `DOCKER-USER`.
Без разрешающих правил телефон подключался к Wi-Fi,
но интернет через VPN не работал.

Установить скрипт:

```bash
sudo install -m 755 scripts/lg-vpn-share.sh \
  /usr/local/sbin/lg-vpn-share.sh
```

Запустить вручную:

```bash
sudo /usr/local/sbin/lg-vpn-share.sh
```

Проверить правила:

```bash
sudo iptables -L DOCKER-USER -n -v
```

Ожидаются два разрешённых направления:

```text
wlp8s0f3u4u4 -> amn0           source 10.42.0.0/24
amn0 -> wlp8s0f3u4u4           destination 10.42.0.0/24
                               ESTABLISHED,RELATED
```

## 5. Установить systemd-службу

```bash
sudo install -m 644 systemd/lg-vpn-share.service \
  /etc/systemd/system/lg-vpn-share.service

sudo systemctl daemon-reload
sudo systemctl enable --now lg-vpn-share.service
```

Проверка:

```bash
sudo systemctl status lg-vpn-share.service
```

В нашей проверке служба получила состояние:

```text
Active: active (exited)
ExecStart: status=0/SUCCESS
```

Повторное применение правил:

```bash
sudo systemctl restart lg-vpn-share.service
```

Эта команда не перезапускает Docker-контейнеры.

## 6. Проверка с телефона или LG webOS

1. Подключить AmneziaVPN на Fedora.
2. Подключить телефон или LG к Wi-Fi-точке доступа.
3. Проверить доступ в интернет.
4. Проверить внешний IP на подключённом устройстве и убедиться,
   что он соответствует VPN, а не обычному провайдеру.

Наличие интернета само по себе ещё не доказывает,
что весь трафик устройства проходит через VPN.

## Что уже проверено

- Телефон подключился к точке доступа.
- После добавления правил в `DOCKER-USER` интернет заработал.
- Счётчики обоих правил увеличивались.
- systemd-служба успешно запускалась.
- Автоподключение `Home-WiFi` включено.

## Что ещё нужно проверить

- Полный цикл перезагрузки Fedora.
- Автоматический запуск AmneziaVPN, если он нужен.
- Поведение после перезапуска Docker.
- Доступность точки доступа после повторного подключения Wi-Fi-адаптера.
- Корректный обход VPN для отдельных видеосервисов.

## Ограничения

- Компьютер Fedora должен быть включён.
- VPN должен быть подключён.
- Правила рассчитаны на конкретные имена интерфейсов и подсеть.
- Если Docker пересоздаст цепочку `DOCKER-USER`, правила
  может потребоваться применить повторно.
- Site-based split tunneling в AmneziaVPN не гарантирует
  такой же обход VPN для устройств за Wi-Fi-точкой доступа.

## Безопасность

Не публикуйте:

- конфигурации AmneziaVPN/WireGuard с приватными ключами;
- пароль Wi-Fi;
- токены и файлы с учётными данными;
- реальные секреты из журналов и конфигураций.
