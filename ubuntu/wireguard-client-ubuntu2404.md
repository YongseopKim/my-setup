# WireGuard 클라이언트 설정 — Ubuntu 24.04 노트북

> 태블릿(4G/LTE) USB 테더링 환경에서도 동일하게 동작함.

## 사전 준비: 서버에서 client2 키 생성

노트북은 새로운 클라이언트이므로, **서버(Ubuntu 22.04)**에서 먼저 키를 만들어야 한다.

```bash
# 서버에서 실행
wg genkey | sudo tee /etc/wireguard/keys/client2.key | wg pubkey | sudo tee /etc/wireguard/keys/client2.pub
sudo chmod 600 /etc/wireguard/keys/client2.key
```

서버 설정에 새 Peer 추가:

```bash
# client2.pub 값 확인
sudo cat /etc/wireguard/keys/client2.pub
```

```bash
# 서버 wg0.conf에 Peer 추가
sudo tee -a /etc/wireguard/wg0.conf << 'EOF'

[Peer]
# 클라이언트 2 (노트북)
PublicKey = <client2.pub 값>
AllowedIPs = 10.0.0.3/32
EOF
```

```bash
# 서버 WireGuard 재시작
sudo systemctl restart wg-quick@wg0
```

---

## 노트북에서 실행할 단계

### 1. WireGuard 설치

```bash
sudo apt update
sudo apt install wireguard
```

### 2. 설정 파일 생성

```bash
sudo tee /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = <client2.key 값>
Address = 10.0.0.3/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = yPNoxwNMlXSEgKdm9vT33G6OnMUyEmX3DKwWeC3pFk0=
Endpoint = vpn.dragonlab.dev:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
```

### 3. 연결 / 해제

```bash
# 연결
sudo wg-quick up wg0

# 상태 확인
sudo wg show

# 테스트
ping 10.0.0.1
curl ifconfig.me    # 집 IP가 나오면 성공

# 해제
sudo wg-quick down wg0
```

### 4. (선택) 부팅 시 자동 연결

```bash
sudo systemctl enable wg-quick@wg0
```

---

## 태블릿 USB 테더링 관련 참고

- USB 테더링 시 네트워크 인터페이스가 `usb0`, `enx...`, `eth1` 등 다양한 이름으로 잡힌다.
- **WireGuard 클라이언트 설정에서는 이 인터페이스 이름을 신경 쓸 필요 없다.** 인터페이스 지정(`PostUp`/`PostDown` 등)은 서버 쪽에서 NAT을 위해 필요한 것이고, 클라이언트는 기본 라우팅만 따라가므로 인터넷이 연결되어 있기만 하면 동작한다.
- 즉, Wi-Fi든 USB 테더링이든 이더넷이든, **인터넷만 되면 VPN은 동일하게 작동한다.**
