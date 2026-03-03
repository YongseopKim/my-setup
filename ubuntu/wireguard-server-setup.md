# WireGuard VPN 서버 구축 가이드

> Ubuntu 22.04 + Cloudflare 도메인 + ipTIME 공유기 환경

## 전체 구조

```
[외부 클라이언트] → vpn.dragonlab.dev (Cloudflare DNS)
    → ipTIME 공유기 (UDP 51820 포트포워딩)
    → Ubuntu 22.04 WireGuard 서버 (10.0.0.1)
```

## VPN 내부 IP 할당

| 기기 | VPN IP |
|---|---|
| 서버 (Ubuntu 22.04) | 10.0.0.1 |
| 클라이언트 1 — 모바일 | 10.0.0.2 |
| 클라이언트 2 — 노트북 | 10.0.0.3 |

---

## 1단계: WireGuard 설치 및 키 생성

```bash
sudo apt update
sudo apt install wireguard

# 키 생성 디렉토리
sudo mkdir -p /etc/wireguard/keys

# 서버 키
wg genkey | sudo tee /etc/wireguard/keys/server.key | wg pubkey | sudo tee /etc/wireguard/keys/server.pub
sudo chmod 600 /etc/wireguard/keys/server.key

# 클라이언트 키 (기기마다 하나씩)
wg genkey | sudo tee /etc/wireguard/keys/client1.key | wg pubkey | sudo tee /etc/wireguard/keys/client1.pub
sudo chmod 600 /etc/wireguard/keys/client1.key
```

> `/etc/wireguard/`는 root 소유 디렉토리이므로 `cd`로 진입 불가. 명령어에 절대 경로를 사용할 것.

## 2단계: 서버 네트워크 인터페이스 확인

```bash
ip route show default
# 출력 예: default via 192.168.0.1 dev enp3s0 proto static metric 100
# → 인터페이스 이름(enp3s0)을 3단계에서 사용
```

## 3단계: 서버 설정

```bash
sudo tee /etc/wireguard/wg0.conf << 'EOF'
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server.key 내용>

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o enp3s0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o enp3s0 -j MASQUERADE

[Peer]
# 클라이언트 1 (모바일)
PublicKey = <client1.pub 내용>
AllowedIPs = 10.0.0.2/32

[Peer]
# 클라이언트 2 (노트북)
PublicKey = <client2.pub 내용>
AllowedIPs = 10.0.0.3/32
EOF
```

- `enp3s0`은 2단계에서 확인한 실제 인터페이스로 교체
- 클라이언트 추가 시 `[Peer]` 블록을 추가하고 IP를 `10.0.0.4/32` 등으로 증가

## 4단계: IP 포워딩 활성화

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

## 5단계: 방화벽

UFW가 활성화되어 있는 경우에만 필요:

```bash
sudo ufw allow 51820/udp
sudo ufw reload
```

## 6단계: 서버 시작

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 상태 확인
sudo wg show
```

## 7단계: ipTIME 포트포워딩

ipTIME 관리페이지(`192.168.0.1`) → **고급 설정 → NAT/라우터 관리 → 포트포워드 설정**:

| 항목 | 값 |
|---|---|
| 규칙이름 | wg |
| 내부 IP | 서버 내부 IP (예: 192.168.0.2) |
| 프로토콜 | **UDP** |
| 외부 포트 | 51820 |
| 내부 포트 | 51820 |

> 프로토콜 목록에 WireGuard가 없으므로 "사용자 정의"로 수동 설정.
> ipTIME 자체 VPN 서버 기능은 비활성화할 것.

## 8단계: Cloudflare DNS 설정

Cloudflare 대시보드에서 A 레코드 추가:

| 항목 | 값 |
|---|---|
| Type | A |
| Name | vpn |
| Content | 공유기 외부 IP |
| Proxy | **DNS only** (회색 구름, 반드시 프록시 끄기) |

> Cloudflare 프록시는 HTTP/HTTPS만 중계하므로, UDP 트래픽인 WireGuard는 프록시를 끄고 DNS 전용으로 사용해야 함.

### Cloudflare DDNS (유동 IP 대응)

5분마다 외부 IP를 확인하여 Cloudflare DNS를 자동 업데이트하는 스크립트:

```bash
sudo tee /usr/local/bin/cf-ddns.sh << 'EOF'
#!/bin/bash
ZONE_ID="<Cloudflare Zone ID>"
RECORD_ID="<DNS Record ID>"
API_TOKEN="<Cloudflare API Token>"
RECORD_NAME="vpn.dragonlab.dev"

IP=$(curl -s https://api.ipify.org)

curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}"
EOF

sudo chmod +x /usr/local/bin/cf-ddns.sh
```

cron 등록 (5분마다 실행):

```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/cf-ddns.sh") | crontab -
```

**Cloudflare API Token 생성 방법:**
1. Cloudflare 대시보드 → My Profile → API Tokens → Create Token
2. "Edit zone DNS" 템플릿의 "Use template" 클릭
3. Zone Resources: `Include - Specific zone - dragonlab.dev` 선택
4. Continue to summary → Create Token

**Record ID 조회 방법:**

```bash
curl -s "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records?name=vpn.dragonlab.dev" \
  -H "Authorization: Bearer <API_TOKEN>" \
  -H "Content-Type: application/json"
```

## 9단계: 클라이언트 설정

### 모바일 (iOS/Android)

WireGuard 앱 설치 후 설정 파일을 전송하여 import:

```ini
[Interface]
PrivateKey = <client1.key 내용>
Address = 10.0.0.2/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <server.pub 내용>
Endpoint = vpn.dragonlab.dev:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

- `AllowedIPs = 0.0.0.0/0`: Full tunnel (모든 트래픽 VPN 경유)
- `AllowedIPs = 10.0.0.0/24, 192.168.0.0/24`: Split tunnel (집 네트워크만)

QR 코드 생성이 가능한 경우:

```bash
sudo apt install qrencode
sudo cat /etc/wireguard/client1.conf | qrencode -t ansiutf8
```

### 노트북 (Ubuntu 24.04)

별도 문서 참조: [wireguard-client-ubuntu2404.md](wireguard-client-ubuntu2404.md)

## 10단계: 연결 테스트

클라이언트에서:

1. Wi-Fi를 끄고 모바일 데이터(또는 외부 네트워크)로 전환
2. WireGuard 연결 활성화
3. 확인:

```bash
# VPN 상태
sudo wg show

# 서버 ping
ping 10.0.0.1

# Full tunnel 확인 — 집 외부 IP가 나와야 함
curl ifconfig.me
```

---

## 재부팅 후 자동 시작 확인

| 서비스 | 자동 시작 |
|---|---|
| WireGuard (`wg-quick@wg0`) | `systemctl enable`로 등록됨 |
| DDNS cron | 유저 crontab — 재부팅 후 유지 |

확인 명령어:

```bash
systemctl is-enabled wg-quick@wg0
systemctl is-enabled cron
crontab -l
```

---

## 키 파일 위치

```
/etc/wireguard/keys/
├── server.key      # 서버 private key (chmod 600)
├── server.pub      # 서버 public key
├── client1.key     # 클라이언트 1 private key (chmod 600)
├── client1.pub     # 클라이언트 1 public key
├── client2.key     # 클라이언트 2 private key (chmod 600)
└── client2.pub     # 클라이언트 2 public key
```

## 클라이언트 추가 방법

```bash
# 서버에서 새 키 생성
wg genkey | sudo tee /etc/wireguard/keys/client3.key | wg pubkey | sudo tee /etc/wireguard/keys/client3.pub
sudo chmod 600 /etc/wireguard/keys/client3.key

# wg0.conf에 [Peer] 블록 추가
sudo tee -a /etc/wireguard/wg0.conf << 'EOF'

[Peer]
PublicKey = <client3.pub 내용>
AllowedIPs = 10.0.0.4/32
EOF

# WireGuard 재시작
sudo systemctl restart wg-quick@wg0
```
