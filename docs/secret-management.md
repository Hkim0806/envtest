# 비밀정보 운영 가이드 (SOPS + age)

## 원칙

- Git 저장: `.env.enc`
- 로컬 사용: `.env`
- 사용자 입력값 표기: `["..."]`

## 설치

레포:
```bash
git clone ["YOUR_REPO_URL"]
cd ["YOUR_REPO_DIR"]
```

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

## 초기 설정

공개키 확인:
```bash
age-keygen -y ["YOUR_AGE_KEY_FILE_PATH"]
```

`.sops.yaml` 공개키 등록:
```yaml
- ["YOUR_AGE_PUBLIC_KEY"]
```

## 암호화 / 복호화

암호화:
```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
```

복호화 확인:
```bash
sops decrypt --filename-override .env .env.enc
```

## IDE / 실행

IDE:
```bash
./scripts/open-ide.sh ["YOUR_IDE_COMMAND"]
```

명령:
```bash
./scripts/run-with-env.sh ["YOUR_RUN_COMMAND"]
```

## 팀원 추가/제거

추가:
```bash
sops updatekeys .env.enc
```

제거:
```bash
sops rotate -i .env.enc
```

## hook

global 권고:
```bash
git config --global core.hooksPath ["YOUR_GLOBAL_HOOKS_DIR"]
```

주의:
- global 설정은 다른 레포에도 영향이 갈 수 있습니다.

