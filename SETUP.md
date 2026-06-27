# Tesla Flutter 앱 설정 가이드

## 필요한 것
- Flutter SDK 3.x 이상
- Android Studio 또는 VS Code
- Tesla 계정

---

## 1단계 — Flutter 설치

```bash
# Flutter 공식 사이트에서 다운로드
# https://flutter.dev/docs/get-started/install

flutter doctor  # 설치 확인
```

---

## 2단계 — Tesla Developer 앱 등록

1. https://developer.tesla.com 접속 → 로그인
2. **Dashboard → Create Application**
3. 입력:
   - **Allowed Origin**: `https://localhost` (필수)
   - **Redirect URI**: `teslapwa://callback`
4. 생성 후 **Client ID** 복사

> 한국 차량은 Region **ap (Asia Pacific)** 선택

---

## 3단계 — Client ID 설정

`lib/config.dart` 파일을 열고:

```dart
static const String clientId = 'YOUR_CLIENT_ID_HERE';
// ↑ 여기를 발급받은 Client ID로 교체
```

---

## 4단계 — 가상 키 등록 (명령 전송 필수)

차량에 명령을 보내려면 앱의 가상 키를 차량에 등록해야 합니다.

Tesla 공식 가이드:
https://developer.tesla.com/docs/fleet-api/virtual-keys/developer-guide

> 데이터 조회(배터리, 온도 등)는 가상 키 없이 가능합니다.

---

## 5단계 — 앱 빌드 & 실행

```bash
cd tesla_flutter

# 패키지 설치
flutter pub get

# 안드로이드 실행
flutter run

# APK 빌드 (배포용)
flutter build apk --release

# iOS 빌드
flutter build ios --release
```

---

## 지원 기능

| 기능 | 지원 |
|------|------|
| **💨 에바포레이터 건조 (5분 자동)** | ✅ |
| 잠금 / 잠금해제 | ✅ |
| 앞/뒤 트렁크 | ✅ |
| 창문 / 충전구 | ✅ |
| 에어컨/히터 + Max Defrost | ✅ |
| 바이오웨폰 방어 모드 | ✅ |
| Dog / Camp 모드 | ✅ |
| 충전 제어 | ✅ |
| 센트리 모드 | ✅ |
| 원격 시동 | ✅ |
| 경적 / 라이트 점멸 | ✅ |
| 붐박스 (외부 스피커) | ✅ |
| HomeLink | ✅ |
| 미디어 제어 | ✅ |
| iOS + Android 동시 지원 | ✅ |
| 서버 불필요 | ✅ |

---

## 에바포레이터 건조 원리

```
1. 차량 깨우기 (wake_up)
2. 에어컨 시작 (auto_conditioning_start)
3. Max Defrost 켜기 (set_preconditioning_max: true)
   → AC 컴프레서 OFF, 최대 히터 가동
4. 온도 최고로 설정 (set_temps: 28°C)
5. 시트 히터 MAX (추가 발열)
6. 5분 카운트다운
7. 모든 것 자동 종료
```

Max Defrost 모드는 AC 컴프레서를 끄고 히터만 작동시켜
에바포레이터에 따뜻한 바람을 순환시킵니다.
이로써 에바포레이터의 수분이 증발하여 에어컨 냄새가 방지됩니다.
