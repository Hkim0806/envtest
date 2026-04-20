# envtest Secret Management Guide

SOPS + age 기반으로 `.env` 비밀값을 안전하게 관리하는 프로젝트 설정입니다.

## Why this setup

- Git에는 암호화 파일(`.env*.enc`)만 저장
- 평문 `.env*`는 커밋 차단
- 팀원 추가/제거를 공개키 갱신으로 처리
- IDE/개발 실행 시 자동으로 환경변수 주입

---

## Project Structure

```text
.
├─ .sops.yaml               # SOPS 암호화 규칙 + age recipients
├─ .gitignore               # 평문 .env 제외, 암호문 추적
├─ .githooks/pre-commit     # 평문 .env staged 차단
├─ scripts/open-ide.sh      # IDE를 sops exec-env로 실행
├─ scripts/run-with-env.sh  # 임의 명령을 sops exec-env로 실행
└─ docs/secret-management.md
```

---

## 1) Install

### age

- macOS: `brew install age`
- Ubuntu/Debian: `sudo apt-get install age`
- Windows: `winget install --id FiloSottile.age` 또는 `scoop install age`

### sops

- macOS: `brew install sops`
- Ubuntu/Debian: `sudo apt-get install sops`
- Windows: `scoop install sops` 또는 릴리스 바이너리 설치

설치 확인:

```bash
sops --version
age --version
age-keygen --version
```

---

## 2) Create age key (1회)

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

공개키 확인:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

중요:

- 공유 가능: `age1...` 공개키
- 절대 공유 금지: `AGE-SECRET-KEY-...` 개인키

---

## 3) Configure recipients (`.sops.yaml`)

팀원 공개키를 `age:` 아래에 추가합니다.

```yaml
creation_rules:
  - path_regex: (^|/)\.env(\.(dev|prod))?(\.enc)?$
    age:
      - age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
      - age1yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy
```

---

## 4) Encrypt / Decrypt

암호화:

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
sops encrypt --input-type dotenv --output-type dotenv --output .env.dev.enc .env.dev
sops encrypt --input-type dotenv --output-type dotenv --output .env.prod.enc .env.prod
```

복호화 확인:

```bash
sops decrypt --filename-override .env .env.dev.enc
```

원칙:

- Git 커밋 대상: `.env*.enc`
- 로컬 전용: `.env*` 평문

---

## 5) Run with injected env

### IDE 실행

```bash
./scripts/open-ide.sh code
./scripts/open-ide.sh cursor
./scripts/open-ide.sh idea
./scripts/open-ide.sh --env-file .env.dev.enc
```

인자 없으면 자동 탐색 우선순위:

`code -> cursor -> windsurf -> idea -> pycharm -> webstorm -> phpstorm -> goland -> rider -> studio -> nvim -> vim`

### 임의 명령 실행

```bash
./scripts/run-with-env.sh npm run dev
./scripts/run-with-env.sh --env-file .env.prod.enc -- npm run start
```

---

## 6) Git safety guard (필수)

훅 활성화:

```bash
git config core.hooksPath .githooks
```

동작:

- staged 파일에 평문 `.env*`가 있으면 커밋 실패
- 선택 옵션: `AUTO_ENCRYPT_ENV=1 git commit` 시 `.env -> .env.enc` 자동 갱신 시도

권장:

- 기본은 자동 갱신보다 "차단 모드"를 사용
- 자동 갱신은 보조 기능으로만 사용

---

## 7) Team operations

### Add teammate (`updatekeys`)

1. `.sops.yaml`에 공개키 추가
2. 암호문 recipient 갱신

```bash
sops updatekeys .env.enc
sops updatekeys .env.dev.enc
sops updatekeys .env.prod.enc
```

### Remove teammate (`rotate`)

1. `.sops.yaml`에서 공개키 제거
2. 데이터 키 재발급

```bash
sops rotate -i .env.enc
sops rotate -i .env.dev.enc
sops rotate -i .env.prod.enc
```

핵심 차이:

- `updatekeys`: 접근 대상(수신자)만 갱신, 주로 추가 시
- `rotate`: 데이터 키 자체 재생성, 제거 시 필수

---

## 8) 실수 방지 체크리스트

- 개인키를 메신저/이메일로 공유하지 않는다.
- `.env*.enc` 변경은 리뷰 없이 머지하지 않는다.
- 팀원 제거/권한 변경 시 당일 `rotate` 수행한다.
- CI/CD에는 개발자 개인키 대신 배포 전용 키를 사용한다.

---

## 9) Troubleshooting

- `sops: command not found`
  - PATH 설정 후 터미널 재시작
- `failed to load age identities`
  - `SOPS_AGE_KEY_FILE` 또는 기본 키 경로 확인
- `no matching creation rules found`
  - `.sops.yaml`의 `path_regex`와 파일명 패턴 확인

---

## Related doc

- 상세 운영 문서: [docs/secret-management.md](./docs/secret-management.md)

