# WireGuard 클라이언트 — 맥미니 (상시 접속)

> VPN IP: `10.0.0.5` / **Split tunnel** / launchd 상시 구동
>
> 목적: **외부에서 VPN 주소(`10.0.0.5`)로 맥미니에 접속**한다 (SSH, 화면 공유 등).
> 맥미니는 서버와 같은 LAN에 고정 설치된 상시 가동 머신이라는 전제다.

M1 맥북 설정([wireguard-client-macos.md](./wireguard-client-macos.md))과 **구성이 다르다.**
아래 "설계 결정" 항목의 이유로 엔드포인트와 AllowedIPs, 구동 방식이 모두 다르므로
그 문서를 그대로 따라 하면 안 된다.

## 설계 결정

| 항목 | 이 문서 (맥미니) | 일반 클라이언트 (맥북 등) | 이유 |
|---|---|---|---|
| Endpoint | `192.168.0.2:51820` (서버 LAN IP) | `vpn.dragonlab.dev:51820` | 맥미니는 서버와 같은 LAN에 고정 설치다. 공인 IP로 나갔다 돌아오는 NAT 헤어핀에 의존할 이유가 없다. 공유기 설정 하나에 연결성을 걸지 않는다. |
| AllowedIPs | `10.0.0.0/24` (split) | `0.0.0.0/0` (full) | 목적이 "외부에서 맥미니로 들어오는 접속"이므로 VPN 대역만 터널로 보내면 충분하다. full tunnel로 두면 맥미니의 모든 인터넷 트래픽이 바로 옆 서버를 거쳐 나가 불필요한 우회가 생긴다. |
| 구동 | launchd **시스템 데몬** | App Store 앱 (수동 토글) | 상시 접속 대상이므로 사용자 로그인 세션에 의존하면 안 된다. 재부팅 후 자동 연결되어야 한다. |
| DNS | 지정하지 않음 | `1.1.1.1, 8.8.8.8` | split tunnel이라 기존 DNS를 그대로 쓴다. |

**단, 맥미니를 밖으로 옮길 계획이 생기면** Endpoint를 도메인으로 바꾸어야 한다.

## 1. 클라이언트 설치

macOS에는 커널 모듈이 없으므로 `wireguard-go`가 함께 필요하다 (의존성으로 자동 설치됨).

```bash
brew install wireguard-tools wireguard-go
wg --version
```

`wg-quick`이 설정을 찾는 경로는 다음 순서다. 이 문서는 첫 번째를 쓴다.

```
/etc/wireguard  /usr/local/etc/wireguard  /opt/homebrew/etc/wireguard
```

## 2. 서버에 피어 등록

서버(root)에서:

```bash
umask 077
mkdir -p /etc/wireguard/keys /etc/wireguard/clients

# 백업 먼저
cp -a /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak-$(date +%Y%m%d-%H%M%S)

# 키쌍 생성
wg genkey | tee /etc/wireguard/keys/macmini.key | wg pubkey > /etc/wireguard/keys/macmini.pub

# 피어 등록
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# 맥미니 (mmn2pro) - 상시 접속, 같은 LAN
PublicKey = $(cat /etc/wireguard/keys/macmini.pub)
AllowedIPs = 10.0.0.5/32
EOF

# 무중단 반영 — 접속 중인 다른 피어의 연결을 끊지 않는다
wg syncconf wg0 <(wg-quick strip wg0)
wg show wg0 peers
```

> `wg-quick down/up`을 쓰면 **접속 중인 모든 피어가 끊긴다.** 피어 추가/삭제에는 `wg syncconf`를 쓴다.

클라이언트 설정 생성:

```bash
cat > /etc/wireguard/clients/macmini.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/keys/macmini.key)
Address = 10.0.0.5/24

[Peer]
PublicKey = $(wg show wg0 public-key)
Endpoint = 192.168.0.2:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/clients/macmini.conf
```

`PersistentKeepalive`는 서버가 맥미니의 엔드포인트를 항상 알고 있게 해준다.
외부에서 맥미니로 **들어오는** 접속이 목적이므로 이 값이 없으면 안 된다.

## 3. 설정 가져오기 (맥미니에서)

개인키가 화면과 셸 히스토리에 남지 않도록 파일로 바로 받는다.

```bash
ssh -t 192.168.0.2 'sudo cat /etc/wireguard/clients/macmini.conf' > ~/wg0.conf
chmod 600 ~/wg0.conf

sudo mkdir -p /etc/wireguard
sudo install -o root -g wheel -m 600 ~/wg0.conf /etc/wireguard/wg0.conf
rm -P ~/wg0.conf          # 안전 삭제
```

## 4. launchd 상시 구동

```bash
sudo tee /Library/LaunchDaemons/com.wireguard.wg0.plist > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wireguard.wg0</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/wg-quick</string>
        <string>up</string>
        <string>wg0</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/var/log/wireguard-wg0.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/wireguard-wg0.log</string>
</dict>
</plist>
EOF

sudo chown root:wheel /Library/LaunchDaemons/com.wireguard.wg0.plist
sudo chmod 644 /Library/LaunchDaemons/com.wireguard.wg0.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.wireguard.wg0.plist
```

> `KeepAlive`는 반드시 `false`다. `wg-quick up`은 터널을 올린 뒤 **종료되는** 명령이라,
> `true`로 두면 launchd가 끝없이 재실행한다.

제어 명령:

```bash
sudo launchctl kickstart -k system/com.wireguard.wg0   # 재시작
sudo launchctl bootout system/com.wireguard.wg0        # 중지 및 등록 해제
tail -f /var/log/wireguard-wg0.log                     # 로그
```

## 5. 검증

맥미니에서:

```bash
sudo wg show                      # latest handshake 가 찍히는지
ifconfig | grep 10.0.0.5          # utunN 에 주소 할당 확인
netstat -rn -f inet | grep utun   # 10/24 라우트가 있는지 (macOS는 10/24 로 축약 표기)
ping -c 3 10.0.0.1                # 서버 도달
```

서버에서 — **반대 방향이 진짜 검증이다:**

```bash
ping -c 3 10.0.0.5
timeout 3 bash -c 'echo > /dev/tcp/10.0.0.5/22'    && echo "SSH 열림"
timeout 3 bash -c 'echo > /dev/tcp/10.0.0.5/5900'  && echo "화면공유 열림"
```

최종적으로 **외부 네트워크의 다른 피어**(노트북, 폰)에서 VPN을 켜고:

```bash
ssh dragon@10.0.0.5
```

피어 간 통신에는 서버의 `net.ipv4.ip_forward=1`과 `wg0` 방향 `FORWARD` ACCEPT 규칙이 필요하다
(서버 `wg0.conf`의 `PostUp`에 포함되어 있다).

## 트러블슈팅

**터널이 안 올라온다**
`/var/log/wireguard-wg0.log`를 먼저 본다. `wg-quick`이 `bash`를 요구하므로
`brew install bash`가 되어 있어야 한다 (`wireguard-tools` 의존성에 포함).

**`latest handshake`가 안 찍힌다**
서버에 피어가 등록됐는지 `sudo wg show wg0 peers`로 확인한다.
설정 파일에만 적고 `wg syncconf`를 안 하면 커널에 반영되지 않는다.

**외부에서 `10.0.0.5`에 못 붙는다**
접속하는 쪽 클라이언트의 `AllowedIPs`에 `10.0.0.0/24`가 포함되는지 확인한다.
`0.0.0.0/0`이면 포함된다.

**LAN IP(`192.168.0.x`)로 접근하려 하지 말 것**
서버의 `MASQUERADE` 때문에 출처가 전부 서버 IP로 보이고,
접속하는 쪽 네트워크가 `192.168.0.0/24`이면 자기 로컬 대역과 겹쳐 아예 터널로 들어가지 않는다.
VPN 주소를 쓰면 이 문제가 없다.

## 참고

- 맥미니에 유선(en0)과 Wi-Fi(en1)가 **같은 서브넷에 동시 활성**이면 비대칭 경로가 생길 수 있다.
  VPN 주소로 접근하는 이 구성에서는 영향이 작지만, 하나만 쓰는 편이 깔끔하다.
- NordVPN 등 다른 VPN을 켜면 기본 라우트를 가져가며 충돌할 수 있다.
  split tunnel이라 `10.0.0.0/24`만 겹치지 않으면 공존은 가능하다.
- 키 유출 시 대응은 [wireguard-client-macos.md](./wireguard-client-macos.md)의 "키를 교체해야 할 때"를 따른다.
  **파일에서 키를 지우는 것만으로는 무효화되지 않는다. 서버에서 피어를 제거해야 한다.**
