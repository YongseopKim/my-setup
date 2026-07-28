# WireGuard 클라이언트 설정 — macOS (M1 맥북)

> VPN IP: `10.0.0.4` / Full tunnel 모드

## 1. WireGuard 앱 설치

App Store에서 "WireGuard"를 검색하여 설치하거나:

```bash
brew install wireguard-tools
```

> App Store 버전은 메뉴바에서 VPN 토글이 가능하여 더 편리하다.

## 2. 키 발급 (서버에서)

> **개인키는 절대 저장소에 커밋하지 않는다.** 아래 절차대로 서버에서 발급하고,
> 클라이언트로는 파일째 안전하게 옮긴다. 문서에 평문으로 적지 않는다.

서버(root)에서:

```bash
umask 077
mkdir -p /etc/wireguard/keys /etc/wireguard/clients

# 키쌍 생성
wg genkey | tee /etc/wireguard/keys/client3-m1.key | wg pubkey > /etc/wireguard/keys/client3-m1.pub

# 서버에 피어 등록
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# 클라이언트 3 (M1 맥북)
PublicKey = $(cat /etc/wireguard/keys/client3-m1.pub)
AllowedIPs = 10.0.0.4/32
EOF

# 무중단 반영 (기존 피어 연결을 끊지 않는다)
wg syncconf wg0 <(wg-quick strip wg0)
```

클라이언트 설정 파일 생성:

```bash
cat > /etc/wireguard/clients/client3-m1.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/keys/client3-m1.key)
Address = 10.0.0.4/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $(wg show wg0 public-key)
Endpoint = vpn.dragonlab.dev:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 /etc/wireguard/clients/client3-m1.conf
```

## 3. 설정 파일 가져오기 (맥북에서)

개인키가 화면(및 셸 히스토리)에 남지 않도록 파일로 바로 받는다:

```bash
ssh -t <서버> 'sudo cat /etc/wireguard/clients/client3-m1.conf' > ~/wg0.conf
chmod 600 ~/wg0.conf
```

**앱에 Import한 뒤에는 이 파일을 삭제한다:**

```bash
rm -P ~/wg0.conf
```

## 4. 연결

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

## 5. 연결 테스트

외부 네트워크(모바일 핫스팟 등)에서 VPN을 켠 뒤:

```bash
# 서버 ping
ping 10.0.0.1

# Full tunnel 확인 — 집 외부 IP가 나와야 함
curl ifconfig.me
```

## 키를 교체해야 할 때 (유출 등)

기존 피어를 지우고 새 키로 다시 등록한다. 공개키만 바꾸면 되며 VPN IP는 재사용해도 된다.

```bash
# 1) 백업
cp -a /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak-$(date +%Y%m%d-%H%M%S)

# 2) 해당 [Peer] 블록을 삭제한 뒤, 위 "2. 키 발급" 절차를 다시 수행

# 3) 반영 및 확인
wg syncconf wg0 <(wg-quick strip wg0)
wg show wg0 peers   # 옛 공개키가 목록에서 사라졌는지 확인
```

유출된 키는 파일이나 문서에서 지우는 것만으로는 무효화되지 않는다.
**반드시 서버에서 피어를 제거해야** 접속이 차단된다.
git 히스토리에 한번 올라간 키는 회수할 수 없으므로 폐기가 유일한 대응이다.

## 참고

- macOS App Store 버전은 `/etc/wireguard/`를 사용하지 않고 앱 자체 저장소에 설정을 보관한다.
- CLI(`wg-quick`)와 App Store 앱은 독립적으로 동작하므로, 둘 다 설치한 경우 설정이 이중으로 존재할 수 있다. 하나만 사용하는 것을 권장한다.
