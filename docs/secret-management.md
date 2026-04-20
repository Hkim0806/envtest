# 비밀정보 관리 가이드 (SOPS + age)

이 문서는 우리 프로젝트에서 `.env` 비밀정보를 안전하게 관리하기 위한 표준 절차입니다.

## 목적

- Git에는 암호화 파일(`.env*.enc`)만 저장
- 평문 `.env*`는 로컬에만 보관
- 각 개발자는 본인 `age` 개인키만 로컬 보관
- 팀원 추가/제거를 공개키 갱신으로 처리

## 구성 파일

- `.sops.yaml`: 암호화 규칙 + age 공개키(recipient) 목록
- `.gitignore`: 평문 `.env*` 추적 차단
- `.githooks/pre-commit`: 평문 `.env*` staged 시 커밋 차단
- `scripts/open-ide.sh`: IDE를 `sops exec-env`로 실행
- `scripts/run-with-env.sh`: 임의 명령을 `sops exec-env`로 실행

## 1) 설치

### age 설치

- macOS: `brew install age`
- Ubuntu/Debian: `sudo apt-get install age`
- Windows: `winget install --id FiloSottile.age` 또는 `scoop install age`

### sops 설치

- macOS: `brew install sops`
- Ubuntu/Debian: `sudo apt-get install sops`
- Windows: `scoop install sops` 또는 릴리스 바이너리 설치

설치 확인:

```bash
sops --version
age --version
age-keygen --version
```

## 2) age 키 생성

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

공개키 확인:

```bash
age-keygen -y ~/.config/sops/age/keys.txt
```

- 공유 대상: `age1...` 공개키
- 공유 금지: `AGE-SECRET-KEY-...` 개인키

## 3) `.sops.yaml` 반영

1. 팀원 공개키를 `.sops.yaml`의 `age:` 목록에 추가
2. 규칙은 `.env`, `.env.dev`, `.env.prod` 및 `.enc` 변형에 적용
3. 키 변경 후 암호문 갱신(`updatekeys` 또는 `rotate`) 수행

## 4) `.env` 암호화

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
sops encrypt --input-type dotenv --output-type dotenv --output .env.dev.enc .env.dev
sops encrypt --input-type dotenv --output-type dotenv --output .env.prod.enc .env.prod
```

- Git 커밋: `.env*.enc`만
- 평문 `.env*`: 커밋 금지(로컬 전용)

## 5) 복호화 확인

```bash
sops decrypt --filename-override .env .env.enc
```

가능하면 파일로 저장하지 말고 터미널 출력으로만 확인합니다.

## 6) IDE 실행 방법

```bash
./scripts/open-ide.sh code
./scripts/open-ide.sh cursor
./scripts/open-ide.sh idea
```

다른 암호문 사용:

```bash
./scripts/open-ide.sh --env-file .env.dev.enc
```

인자 생략 시 자동 탐색 우선순위:

`code -> cursor -> windsurf -> idea -> pycharm -> webstorm -> phpstorm -> goland -> rider -> studio -> nvim -> vim`

## 7) 범용 실행 스크립트

```bash
./scripts/run-with-env.sh npm run dev
./scripts/run-with-env.sh --env-file .env.prod.enc -- npm run start
```

## 8) 지원 IDE/에디터

- `code`
- `cursor`
- `windsurf`
- `idea`
- `pycharm`
- `webstorm`
- `phpstorm`
- `goland`
- `rider`
- `studio`
- `nvim`
- `vim`

## 9) 팀원 추가 절차 (`updatekeys`)

1. 신규 팀원 공개키를 `.sops.yaml`에 추가
2. 기존 암호문 recipient 갱신

```bash
sops updatekeys .env.enc
sops updatekeys .env.dev.enc
sops updatekeys .env.prod.enc
```

3. `.sops.yaml` + 변경된 `.env*.enc` 커밋

## 10) 팀원 제거 절차 (`rotate`)

1. 제거 대상 공개키를 `.sops.yaml`에서 삭제
2. 데이터 키 재발급(필수)

```bash
sops rotate -i .env.enc
sops rotate -i .env.dev.enc
sops rotate -i .env.prod.enc
```

3. `.sops.yaml` + 변경된 `.env*.enc` 커밋

## 11) `updatekeys` vs `rotate`

- `updatekeys`: recipient 목록 갱신(주로 팀원 추가)
- `rotate`: 데이터 키 자체 재생성(팀원 제거 시 필수)

## 12) Git hook 설정 (필수)

```bash
git config core.hooksPath .githooks
```

기본 동작:

- staged 파일에 평문 `.env*`가 있으면 커밋 실패

선택 동작:

- `AUTO_ENCRYPT_ENV=1 git commit` 시 `.env -> .env.enc` 자동 갱신 시도

권장:

- 기본은 차단 모드 사용
- 자동 갱신은 보조 기능으로만 사용

## 13) 운영 주의사항

- 개인키는 절대 공유하지 않습니다.
- `.env*.enc` 변경은 반드시 코드리뷰합니다.
- 팀원 제거/키 유출 의심 시 즉시 `rotate` 수행합니다.
- CI/CD에는 개발자 개인키 대신 배포 전용 키를 사용합니다.

