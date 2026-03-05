# WireGuard 클라이언트 설정 — macOS (M1 맥북)

> VPN IP: `10.0.0.4` / Full tunnel 모드

## 1. WireGuard 앱 설치

App Store에서 "WireGuard"를 검색하여 설치하거나:

```bash
brew install wireguard-tools
```

> App Store 버전은 메뉴바에서 VPN 토글이 가능하여 더 편리하다.

## 2. 설정 파일 생성

아래 내용을 `wg0.conf`로 저장한다:

```ini
[Interface]
PrivateKey = CNV46atgqNsbGS8givajvMl0nB/wUKNDnmeKimKvxHg=
Address = 10.0.0.4/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = yPNoxwNMlXSEgKdm9vT33G6OnMUyEmX3DKwWeC3pFk0=
Endpoint = vpn.dragonlab.dev:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## 3. 연결

### App Store 앱 사용 시

1. WireGuard 앱 실행
2. **Import tunnel(s) from file** 클릭
3. `wg0.conf` 파일 선택
4. **Activate** 토글로 연결/해제

### CLI 사용 시 (brew 설치)

```bash
# 설정 파일 복사
sudo mkdir -p /etc/wireguard
sudo cp wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf

# 연결
sudo wg-quick up wg0

# 상태 확인
sudo wg show

# 해제
sudo wg-quick down wg0
```

## 4. 연결 테스트

외부 네트워크(모바일 핫스팟 등)에서 VPN을 켠 뒤:

```bash
# 서버 ping
ping 10.0.0.1

# Full tunnel 확인 — 집 외부 IP가 나와야 함
curl ifconfig.me
```

## 참고

- macOS App Store 버전은 `/etc/wireguard/`를 사용하지 않고 앱 자체 저장소에 설정을 보관한다.
- CLI(`wg-quick`)와 App Store 앱은 독립적으로 동작하므로, 둘 다 설치한 경우 설정이 이중으로 존재할 수 있다. 하나만 사용하는 것을 권장한다.
