# envtest Secret Management (SOPS + age)

이 문서는 팀이 `.env`를 안전하게 공유/운영하기 위한 실무 가이드입니다.

핵심 목적:

- Git에는 암호화 파일만 올린다 (`.env.enc`)
- 팀원은 레포만 받아도 `.env`를 복호화해서 바로 사용할 수 있다
- 평문 `.env` 실수 커밋은 hook으로 차단한다

---

## 팀 기본 운영 방식


1. 각 개발자는 본인 PC에서 초기설정 1회 한다
2. 평소 개발은 로컬 평문 `.env`로 개발한다
3. `.env` 값을 바꿨으면 커밋 전에 `.env.enc`를 다시 만든다
4. Git에는 `.env.enc`만 커밋한다 (`.env`는 금지)

---

## 빠른 시작 (처음 1회)

### 1) 레포 클론

```bash
git clone https://github.com/Hkim0806/envtest.git
cd envtest
```

### 2) 설치 + 초기설정 자동 실행 (OS별 하나만)

Windows:

```bat
.\install\setup-secrets-windows.bat
```

macOS:

```bash
chmod +x ./install/setup-secrets-macos.sh
./install/setup-secrets-macos.sh
```

Linux:

```bash
chmod +x ./install/setup-secrets-linux.sh
./install/setup-secrets-linux.sh
```

이 단계에서 자동으로 처리됨:

- sops/age 설치
- PATH 설정
- age 키 생성
- `SOPS_AGE_KEY_FILE` 설정
- 공개키 출력

### 3) 새 터미널 열기

PATH/환경변수 반영을 위해 필요합니다.

### 4) hook 활성화 (각 repo마다 1회)

```bash
git config core.hooksPath .githooks
```

중요:

- hook은 “한 명만” 설정하는 게 아닙니다.
- **각자 로컬 repo마다 직접 1회** 설정해야 합니다.

(선택사항)

git hook 전역 설정
```
git config --grobal core.hooksPath .githooks
```
이 설정은 전역 설정이기에 organization이 아닌 다른 repo의 env 커밋이 막힐 수 있음.

---

## 빠른 시작 다음에는 어디로?

상황별로 바로 이 섹션으로 가면 됩니다.

- “바로 개발 시작” -> [개발 흐름](#개발-흐름)
- “env 값을 바꿨다” -> [언제 어떤 명령을 치나](#언제-어떤-명령을-치나)
- “새 팀원 들어왔다/나갔다” -> [팀원 추가/제거](#팀원-추가제거-envenc-하나-기준)

---

## 개발 흐름

### 옵션 A) 기존처럼 평문 `.env`로 실행

- 로컬 `.env`를 사용해 개발
- 필요할 때만 `.env.enc` 갱신 후 커밋

### 옵션 B) 실행 시 자동 주입 방식

```bash
./scripts/run-with-env.sh npm run dev
```

또는 IDE를 env 주입 상태로 실행:

```bash
./scripts/open-ide.sh code
```

`open-ide.sh`가 하는 일:

- `.env.enc`를 실행 시점에 복호화
- 환경변수를 IDE 프로세스에 주입
- IDE는 해당 환경으로 프로젝트를 엽니다

즉 “IDE 명령 실행”은 IDE를 켜는 방식 중 하나이며, 주입형 실행입니다.

---

## 언제 어떤 명령을 치나

### A. 처음 env를 만들 때 (1회)

1. 로컬 `.env` 작성
2. 암호화 파일 생성

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
```

### B. `.env` 값을 수정했을 때 (매번)

아래 명령으로 `.env.enc`를 갱신:

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
```

그리고 `.env.enc`만 커밋.

### C. 다른 팀원이 올린 `.env.enc`를 받았을 때

필요하면 확인:

```bash
sops decrypt --filename-override .env .env.enc
```

주의:

- 평소에는 꼭 복호화 명령을 매번 칠 필요는 없습니다.
- 로컬 `.env`로 개발한다면 변경 시점에 암호화만 해주면 됩니다.

---

## 팀원 추가/제거 (`.env.enc` 하나 기준)

문서에 3줄(`.env.enc`, `.env.dev.enc`, `.env.prod.enc`)이 있던 이유는
멀티 환경 파일을 쓰는 팀도 지원하기 위해서였습니다.

우리처럼 `.env.enc`만 쓰면 한 줄만 쓰면 됩니다.

### 팀원 추가

1. 신규 팀원 공개키를 `.sops.yaml`에 추가
2. recipient 갱신

```bash
sops updatekeys .env.enc
```

### 팀원 제거

1. 제거 대상 공개키를 `.sops.yaml`에서 삭제
2. 데이터 키 재생성(필수)

```bash
sops rotate -i .env.enc
```

---
## hook 관련 유의사항

- 로컬 Git 설정이라서 각 repo당 1회씩 필요합니다.

- hook 설정 안 하면 사용에 문제는 없지만 평문 `.env` 실수 커밋 위험이 커집니다.

---

## 커밋 규칙 (요약)

- 커밋 가능: `.env.enc`
- 커밋 금지: `.env`, `.env.*` 평문
- 권장: `.env.enc` 변경은 리뷰 후 머지

---

## 참고 문서

- 상세 운영 문서: [docs/secret-management.md](./docs/secret-management.md)
- 상급자 보고 문서: [docs/secret-management-report.md](./docs/secret-management-report.md)

