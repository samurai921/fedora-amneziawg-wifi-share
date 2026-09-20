# Fedora + AmneziaWG 2: раздача VPN через Wi-Fi

Настройка раздачи интернет-соединения через AmneziaWG 2 с компьютера Fedora
на телевизор LG webOS, телефон и другие устройства через Wi-Fi-точку доступа.

В этой конфигурации Fedora получает интернет по Ethernet, подключается к VPN
через AmneziaVPN и раздаёт соединение по отдельному Wi-Fi-адаптеру.

## Схема сети

```text
Интернет
   |
   | Ethernet
   v
Fedora: enp4s0
   |
   | AmneziaVPN / AmneziaWG 2
   v
VPN-интерфейс: amn0
   |
   | Пересылка IPv4 + NAT + правила firewall
   v
Wi-Fi-адаптер: wlp8s0f3u4u4
   |
   | Точка доступа: TP-Link_5G
   | Профиль NetworkManager: Home-WiFi
   v
LG webOS / телефон / другие устройства
```

## Параметры нашей конфигурации

| Параметр | Значение |
|---|---|
| ОС | Fedora |
| Основной интернет | Ethernet `enp4s0` |
| VPN | AmneziaVPN, протокол AmneziaWG 2 |
| VPN-интерфейс | `amn0` |
| Wi-Fi-адаптер | `wlp8s0f3u4u4` |
| Имя профиля NetworkManager | `Home-WiFi` |
| Имя Wi-Fi-сети (SSID) | `TP-Link_5G` |
| Режим Wi-Fi | AP / hotspot |
| Адрес Fedora в сети Wi-Fi | `10.42.0.1/24` |
| Подсеть клиентов | `10.42.0.0/24` |
| Firewall | `iptables`, цепочка `DOCKER-USER` |

**Важно:** имена интерфейсов на другом компьютере могут отличаться.
Перед повторением настройки проверьте их и замените в командах и скрипте.

Пароль Wi-Fi, VPN-конфигурация и приватные ключи в этом репозитории
не хранятся.

---

# 1. Предварительные требования

Нужно, чтобы:

- Fedora получала интернет через Ethernet;
- AmneziaVPN был установлен и подключался по протоколу AmneziaWG 2;
- Wi-Fi-адаптер поддерживал режим точки доступа (AP);
- использовался NetworkManager;
- Docker был установлен и создавал цепочку `DOCKER-USER`.

Последний пункт относится именно к **нашей проверенной конфигурации**.
Если Docker не установлен или цепочки `DOCKER-USER` нет, приведённый
скрипт нужно адаптировать под используемый firewall.

Проверить интерфейсы:

```bash
nmcli device status
ip -br address
```

В нашем случае используются:

```text
enp4s0          Ethernet
wlp8s0f3u4u4    Wi-Fi
amn0            AmneziaWG 2
```

Проверить поддержку режима AP:

```bash
nmcli -f WIFI-PROPERTIES.AP device show wlp8s0f3u4u4
```

Ожидается:

```text
WIFI-PROPERTIES.AP: yes
```

---

# 2. Подключить AmneziaVPN

Запустите AmneziaVPN и подключите профиль AmneziaWG 2.

Проверьте, что VPN-интерфейс появился:

```bash
ip -br address show amn0
```

Проверьте маршрут обычного интернет-трафика:

```bash
ip route get 1.1.1.1
```

В нашей конфигурации при подключённом VPN маршрут проходит через `amn0`.

> AmneziaVPN устанавливается и настраивается отдельно. Конфигурация VPN
> с приватными ключами не входит в этот репозиторий.

---

# 3. Создать Wi-Fi-точку доступа

Этот шаг выполняется **один раз**, если профиля `Home-WiFi` ещё нет.

Сначала включите Wi-Fi:

```bash
sudo nmcli radio wifi on
```

Чтобы не записывать пароль в README и не вводить его непосредственно
в команду, запросите пароль в терминале:

```bash
read -rsp "Пароль новой Wi-Fi-сети: " WIFI_PASSWORD
echo
```

Создайте точку доступа:

```bash
sudo nmcli device wifi hotspot \
  ifname wlp8s0f3u4u4 \
  con-name Home-WiFi \
  ssid TP-Link_5G \
  password "$WIFI_PASSWORD"
```

Удалите переменную из текущей оболочки:

```bash
unset WIFI_PASSWORD
```

Используйте пароль длиной не менее 8 символов.

**Не запускайте эту команду повторно, если профиль `Home-WiFi`
уже существует.** Для существующего профиля используйте команду
запуска из следующего раздела.

## Проверить профиль

```bash
nmcli -f \
connection.id,connection.type,connection.interface-name,802-11-wireless.mode,ipv4.method \
connection show Home-WiFi
```

Ожидаемые параметры:

```text
connection.id:              Home-WiFi
connection.type:            802-11-wireless
connection.interface-name:  wlp8s0f3u4u4
802-11-wireless.mode:       ap
ipv4.method:                shared
```

Режим `shared` позволяет NetworkManager организовать локальную сеть,
выдачу адресов клиентам и NAT.

В нашей конфигурации Fedora получила адрес:

```text
10.42.0.1/24
```

а телефон получил адрес из той же подсети `10.42.0.0/24`,
который выдал DHCP-сервер NetworkManager.

---

# 4. Включить автозапуск и проверить точку доступа

Разрешить автоматическое подключение профиля:

```bash
sudo nmcli connection modify Home-WiFi connection.autoconnect yes
```

Запустить существующий профиль вручную:

```bash
sudo nmcli connection up Home-WiFi ifname wlp8s0f3u4u4
```

Проверить состояние:

```bash
nmcli device status
```

Посмотреть IP-адрес Wi-Fi-интерфейса:

```bash
ip -4 address show wlp8s0f3u4u4
```

Подключите телефон к сети `TP-Link_5G` и убедитесь, что он получил
IP-адрес из подсети `10.42.0.0/24`.

На этом этапе телефон может подключаться к Wi-Fi, но ещё не получать
интернет через VPN. Для этого нужны следующие шаги.

---

# 5. Проверить пересылку IPv4

Проверить:

```bash
sysctl net.ipv4.ip_forward
```

Ожидаемое значение:

```text
net.ipv4.ip_forward = 1
```

Если значение `0`, включить пересылку для текущего сеанса:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

NetworkManager в режиме IPv4 `shared` обычно сам настраивает пересылку
и NAT для точки доступа. Перед добавлением дополнительных правил
проверьте существующую конфигурацию.

В нашей системе правило NAT для подсети `10.42.0.0/24` уже существовало.

---

# 6. Проверить маршрут трафика клиентов

При активном AmneziaVPN проверьте маршрут для пакета,
поступившего от клиента Wi-Fi:

```bash
ip route get 1.1.1.1 from 10.42.0.2 iif wlp8s0f3u4u4
```

В нашей конфигурации такой трафик маршрутизировался через `amn0`.

Адрес `10.42.0.2` здесь — пример адреса клиента в подсети точки доступа.
Он не обязан совпадать с фактическим адресом телефона или телевизора.

---

# 7. Разрешить передачу трафика через Docker firewall

## Почему понадобился этот шаг

На нашем компьютере установлен Docker.

Телефон подключался к точке доступа и получал локальный IP-адрес,
но интернет не работал, несмотря на существующий NAT и правильный маршрут.

После добавления двух разрешающих правил в цепочку `DOCKER-USER`
интернет на телефоне заработал.

Правила разрешают:

1. Новые соединения из Wi-Fi-подсети в VPN-интерфейс.
2. Ответный трафик из VPN обратно к Wi-Fi-клиентам.

## Установить скрипт

Из корня репозитория:

```bash
sudo install -m 755 scripts/lg-vpn-share.sh \
  /usr/local/sbin/lg-vpn-share.sh
```

Запустить:

```bash
sudo /usr/local/sbin/lg-vpn-share.sh
```

Посмотреть правила:

```bash
sudo iptables -L DOCKER-USER -n -v
```

Ожидаются два разрешающих правила — сначала трафик из Wi-Fi в VPN,
затем ответный:

```text
Chain DOCKER-USER (1 references)
 pkts bytes target  prot opt in            out           source        destination
    0     0 ACCEPT  all  --  wlp8s0f3u4u4  amn0          10.42.0.0/24  0.0.0.0/0
    0     0 ACCEPT  all  --  amn0          wlp8s0f3u4u4  0.0.0.0/0     10.42.0.0/24  ctstate RELATED,ESTABLISHED
```

Счётчики `pkts` и `bytes` в начале будут нулевыми и вырастут,
когда через точку доступа пойдёт трафик.

Именно эти направления были проверены на нашем компьютере.

> Скрипт рассчитан на наличие цепочки `DOCKER-USER`. Он не является
> универсальной настройкой firewall для всех дистрибутивов и всех
> конфигураций Docker.

---

# 8. Настроить автоматическое применение правил

Установить systemd-службу из репозитория:

```bash
sudo install -m 644 systemd/lg-vpn-share.service \
  /etc/systemd/system/lg-vpn-share.service
```

Перечитать конфигурацию systemd:

```bash
sudo systemctl daemon-reload
```

Включить службу и сразу запустить её:

```bash
sudo systemctl enable --now lg-vpn-share.service
```

Проверить:

```bash
sudo systemctl status lg-vpn-share.service
```

При успешном выполнении одноразовой службы ожидается:

```text
Active: active (exited)
ExecStart: status=0/SUCCESS
```

Состояние `active (exited)` здесь нормально: скрипт выполнил команды
и завершился.

## Повторно применить правила

```bash
sudo systemctl restart lg-vpn-share.service
```

Эта команда не перезапускает Docker-контейнеры.

Если Docker позднее пересоздаст правила firewall, может потребоваться
повторно запустить службу.

---

# 9. Проверить интернет на телефоне или LG webOS

1. Убедитесь, что Fedora подключена к интернету по Ethernet.
2. Подключите AmneziaVPN.
3. Убедитесь, что точка доступа `TP-Link_5G` работает.
4. Подключите телефон или телевизор к этой Wi-Fi-сети.
5. Откройте сайт проверки внешнего IP на подключённом устройстве.
6. Сравните IP с внешним адресом VPN.

**Важно:** наличие интернета ещё не доказывает, что трафик идёт
через VPN. Для этого нужно проверить внешний IP именно на клиенте
Wi-Fi — телефоне или телевизоре.

Проверить счётчики правил во время использования интернета:

```bash
sudo iptables -L DOCKER-USER -n -v
```

В нашей проверке счётчики обоих правил увеличивались, то есть
пакеты проходили в обе стороны.

---

# 10. Проверка после перезагрузки Fedora

Перезагрузить компьютер:

```bash
sudo reboot
```

После загрузки проверить:

```bash
nmcli device status
```

```bash
sudo systemctl status lg-vpn-share.service
```

```bash
sudo iptables -L DOCKER-USER -n -v
```

Если AmneziaVPN не подключается автоматически, подключите его вручную.

Затем подключите телефон или LG к точке доступа и повторите проверку
интернета и внешнего IP.

**Статус проекта:** успешный запуск systemd-службы и передача трафика
через VPN проверены. Полный сценарий после перезагрузки компьютера
ещё требует окончательной проверки.

---

# Диагностика

## Ошибка `No suitable device found`

Пример:

```text
No suitable device found for this connection
```

Проверить устройства:

```bash
nmcli device status
```

Проверить, включён ли Wi-Fi:

```bash
nmcli radio wifi
```

Проверить блокировки адаптера:

```bash
rfkill list
```

Включить Wi-Fi, если он отключён:

```bash
sudo nmcli radio wifi on
```

Проверить привязку профиля:

```bash
nmcli -f \
connection.id,connection.type,connection.interface-name,802-11-wireless.mode \
connection show Home-WiFi
```

Попробовать запустить профиль на конкретном адаптере:

```bash
sudo nmcli connection up Home-WiFi ifname wlp8s0f3u4u4
```

Не удаляйте и не пересоздавайте профиль до выяснения причины ошибки.

## Телефон подключается к Wi-Fi, но интернета нет

Проверить:

```bash
ip route get 1.1.1.1
```

```bash
sysctl net.ipv4.ip_forward
```

```bash
sudo iptables -L DOCKER-USER -n -v
```

Повторно применить правила:

```bash
sudo systemctl restart lg-vpn-share.service
```

Убедиться, что AmneziaVPN подключён и интерфейс `amn0` существует:

```bash
ip -br address show amn0
```

## После перезапуска Docker интернет пропал

Повторно применить правила:

```bash
sudo systemctl restart lg-vpn-share.service
```

Затем проверить:

```bash
sudo iptables -L DOCKER-USER -n -v
```

## Посмотреть журнал службы

```bash
sudo journalctl -u lg-vpn-share.service -b --no-pager
```

---
