# envtest Secret Management (SOPS + age)

이 문서는 `.env` 비밀 정보를 안전하게 공유/운영하기 위한 실무 가이드입니다.

핵심 목표:

- Git에는 암호화 파일만 커밋 (`.env.enc`)
- 팀원은 리포만 받아도 `.env.enc`를 복호화해 사용 가능
- 평문 `.env` 실수 커밋은 hook으로 차단

---

## 기본 운영 방식

1. 각 개발자는 본인 PC에서 초기 설정을 1회 수행
2. 로컬에서는 평문 `.env`로 개발
3. `.env`를 수정하면 커밋 전에 `.env.enc`를 다시 생성
4. Git에는 `.env.enc`만 커밋 (`.env` 커밋 금지)

---

## 빠른 시작 (처음 1회)

### 1) 리포 클론

```bash
git clone https://github.com/Hkim0806/envtest.git
cd envtest
```

### 2) 설치 + 초기설정 자동 실행 (OS별 1개만 실행)

Windows (PowerShell/CMD):

```bat
.\env_encrypt\install\setup-secrets-windows.bat
```

Windows (Git Bash):

```bash
./env_encrypt/install/setup-secrets-windows.sh
```

macOS:

```bash
chmod +x ./env_encrypt/install/setup-secrets-macos.sh
./env_encrypt/install/setup-secrets-macos.sh
```

Linux:

```bash
chmod +x ./env_encrypt/install/setup-secrets-linux.sh
./env_encrypt/install/setup-secrets-linux.sh
```

자동 처리 항목:

- sops/age 설치
- PATH 설정
- age 키 생성
- `SOPS_AGE_KEY_FILE` 설정
- 공개키 출력

### 3) 터미널 재시작

PATH/환경변수 반영을 위해 필요합니다.

### 4) hook 활성화 (각 repo마다 1회)

```bash
git config core.hooksPath .githooks
```

권고 사항 (전역 설정):

```bash
git config --global core.hooksPath .githooks
```

주의:

- 전역 hook은 다른 조직/다른 프로젝트에도 영향을 줄 수 있습니다.
- 가장 안전한 방법은 **프로젝트별(local) hook 설정**입니다.

---

## 개발 흐름

### `.env` 수정 후 (매번)

```bash
./encrypt.bat
```

또는:

```bash
sops --config ./env_encrypt/.sops.yaml --filename-override .env encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
```

그 다음 `.env.enc`만 커밋합니다.

### 팀원이 최신 `.env.enc`를 받았을 때

```bash
./decrypt.bat
```

또는:

```bash
sops decrypt --filename-override .env .env.enc > .env
```

---

## 팀원 추가/제거

### 팀원 추가

1. 새 팀원 공개키를 `env_encrypt/.sops.yaml`에 추가
2. recipient 갱신

```bash
sops updatekeys .env.enc
```

### 팀원 제거

1. 제거 대상 공개키를 `env_encrypt/.sops.yaml`에서 삭제
2. 데이터 키 재생성(필수)

```bash
sops rotate -i .env.enc
```

---

## Hook 관련 주의사항

- Hook은 로컬 Git 설정이므로 개발자마다 1회 설정 필요
- Hook을 설정하지 않아도 사용은 가능하지만, 평문 `.env` 실수 커밋 위험이 커집니다

---

## 커밋 규칙 요약

- 커밋 대상: `.env.enc`
- 커밋 금지: `.env`, `.env.*` 평문

---

## 참고

- 상세 운영 문서: `env_encrypt/docs/secret-management.md` (존재 시)
- 보고 문서: `env_encrypt/docs/secret-management-report.md` (존재 시)
