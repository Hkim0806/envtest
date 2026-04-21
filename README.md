# envtest Secret Management (SOPS + age)

Git에는 암호문(`.env.enc`)만 저장하고, 로컬에서는 안전하게 `.env`를 사용하는 운영 가이드입니다.

## 빠른 시작

1) 레포 클론

```bash
git clone ["YOUR_REPO_URL"]
cd ["YOUR_REPO_DIR"]
```

2) 설치 + 초기설정 (OS별 하나만 실행)

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

3) Git hook 설정 (권고)

global (권고):
```bash
git config --global core.hooksPath ["YOUR_GLOBAL_HOOKS_DIR"]
mkdir -p ["YOUR_GLOBAL_HOOKS_DIR"]
cp .githooks/pre-commit ["YOUR_GLOBAL_HOOKS_DIR"]/pre-commit
chmod +x ["YOUR_GLOBAL_HOOKS_DIR"]/pre-commit
```

local (대안):
```bash
git config core.hooksPath .githooks
```

주의:
- `--global`은 다른 레포에도 영향을 줄 수 있습니다.

---

## 개발자가 실제로 하는 일 (`.env.enc` 하나 기준)

1) 로컬 `.env` 수정
2) 암호문 갱신

```bash
sops encrypt --input-type dotenv --output-type dotenv --output .env.enc .env
```

3) `.env.enc`만 커밋

복호화 확인이 필요할 때만:
```bash
sops decrypt --filename-override .env .env.enc
```

---

## IDE / 실행 명령

IDE 주입 실행:
```bash
./scripts/open-ide.sh ["YOUR_IDE_COMMAND"]
```

예시:
- `["YOUR_IDE_COMMAND"]` = `code`, `cursor`, `idea`, `nvim`

명령 주입 실행:
```bash
./scripts/run-with-env.sh ["YOUR_RUN_COMMAND"]
```

예시:
- `["YOUR_RUN_COMMAND"]` = `npm run dev`

---

## 팀원 추가 / 제거 (`.env.enc` 하나 기준)

팀원 추가:
1) `.sops.yaml`에 공개키 추가
```yaml
- ["YOUR_NEW_MEMBER_AGE_PUBLIC_KEY"]
```
2) 반영
```bash
sops updatekeys .env.enc
```

팀원 제거:
1) `.sops.yaml`에서 공개키 제거
2) 키 재발급
```bash
sops rotate -i .env.enc
```

---

## Organization Rulesets 위치 (안내)

1) `["YOUR_ORGANIZATION"]` 이동  
2) `Settings`  
3) `Code, planning, and automation`  
4) `Repository` -> `Rulesets`  
5) `New ruleset` -> `New branch ruleset`

---

## 참고 문서

- [docs/secret-management.md](./docs/secret-management.md)
- [docs/secret-management-report.md](./docs/secret-management-report.md)

