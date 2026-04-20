# envtest Secret Management

SOPS + age 기반으로 `.env` 비밀정보를 안전하게 관리하기 위한 가이드입니다.

## 빠른 시작

### Windows (설치 + 초기설정 자동화)

레포 루트에서 실행:

```bat
.\install\setup-secrets-windows.bat
```

자동으로 수행:

1. `sops`, `age`, `age-keygen` 설치 (`%USERPROFILE%\bin`)
2. 사용자 PATH 등록
3. age 키 생성 (`%USERPROFILE%\.config\sops\age\keys.txt`)
4. `SOPS_AGE_KEY_FILE` 환경변수 설정
5. 공개키 출력

### macOS (설치 + 초기설정 자동화)

레포 루트에서 실행:

```bash
chmod +x ./install/setup-secrets-macos.sh
./install/setup-secrets-macos.sh
```

자동으로 수행:

1. Homebrew 확인
2. `sops`, `age` 설치
3. age 키 생성 (`~/.config/sops/age/keys.txt`)
4. `SOPS_AGE_KEY_FILE`를 `~/.zshrc` 또는 `~/.bashrc`에 등록
5. 공개키 출력

### Linux (설치 + 초기설정 자동화)

레포 루트에서 실행:

```bash
chmod +x ./install/setup-secrets-linux.sh
./install/setup-secrets-linux.sh
```

자동으로 수행:

1. `sops`, `age`, `age-keygen` 설치 (`~/.local/bin`)
2. `~/.bashrc`, `~/.zshrc`에 PATH / `SOPS_AGE_KEY_FILE` 등록
3. age 키 생성 (`~/.config/sops/age/keys.txt`)
4. 공개키 출력

---

## 기본 원칙

- Git에는 암호화 파일(`.env*.enc`)만 저장
- 평문 `.env*`는 로컬에만 보관
- 팀원 추가는 `updatekeys`, 팀원 제거는 `rotate`
- 개인키(`AGE-SECRET-KEY-...`)는 절대 공유 금지

---

## 수동 설치

### age

- macOS: `brew install age`
- Ubuntu/Debian: `sudo apt-get install age`
- Windows: `winget install --id FiloSottile.age` 또는 `scoop install age`

### sops

- macOS: `brew install sops`
- Ubuntu/Debian: `sudo apt-get install sops`
- Windows: `scoop install sops`

설치 확인:

```bash
sops --version
age --version
age-keygen --version
```

---

## 초기 설정

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

- `age1...`: 팀 공유용 공개키
- `AGE-SECRET-KEY-...`: 개인키 (절대 공유 금지)

---

## 암호화 / 복호화

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
sops encrypt --input-type dotenv --output-type dotenv --output .env.dev.enc .env.dev
sops encrypt --input-type dotenv --output-type dotenv --output .env.prod.enc .env.prod
```

```bash
sops decrypt --filename-override .env .env.dev.enc
```

---

## IDE / 명령 실행

### IDE

```bash
./scripts/open-ide.sh code
./scripts/open-ide.sh cursor
./scripts/open-ide.sh idea
./scripts/open-ide.sh --env-file .env.dev.enc
```

인자 생략 시 자동 탐색 순서:

`code -> cursor -> windsurf -> idea -> pycharm -> webstorm -> phpstorm -> goland -> rider -> studio -> nvim -> vim`

### 임의 명령 실행

```bash
./scripts/run-with-env.sh npm run dev
./scripts/run-with-env.sh --env-file .env.prod.enc -- npm run start
```

---

## 팀 운영

### 팀원 추가 (`updatekeys`)

```bash
sops updatekeys .env.enc
sops updatekeys .env.dev.enc
sops updatekeys .env.prod.enc
```

### 팀원 제거 (`rotate`)

```bash
sops rotate -i .env.enc
sops rotate -i .env.dev.enc
sops rotate -i .env.prod.enc
```

---

## Git 보호 설정 (필수)

```bash
git config core.hooksPath .githooks
```

- 평문 `.env*`가 staged 되면 커밋 차단

---

## 유의사항

- 개인키는 외부 공유 금지
- `.env*.enc` 변경은 반드시 코드리뷰
- 권한 변경/팀원 이탈 시 즉시 `rotate`
- CI/CD는 개인키 대신 배포 전용 키 사용

---

## 상세 문서

- [docs/secret-management.md](./docs/secret-management.md)
