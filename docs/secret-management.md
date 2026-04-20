# Secret Management (SOPS + age)

## Goal
- Commit only encrypted env files to Git (`.env.enc`, `.env.dev.enc`, `.env.prod.enc`).
- Keep each developer's age private key only on their local machine.
- Manage team access by adding/removing age public keys in SOPS recipients.

## Files in this setup
- `.sops.yaml`: SOPS rules and age recipients
- `.gitignore`: blocks plaintext `.env*`, allows `.env*.enc`
- `scripts/open-ide.sh`: opens IDE/editor with env injected via `sops exec-env`
- `scripts/run-with-env.sh`: runs any command with env injected via `sops exec-env`
- `.githooks/pre-commit`: blocks commits when plaintext `.env*` is staged

## 1) Install age
- macOS: `brew install age`
- Ubuntu/Debian: `sudo apt-get install age`
- Windows (Scoop): `scoop install age`

## 2) Install sops
- macOS: `brew install sops`
- Ubuntu/Debian: `sudo apt-get install sops`
- Windows (Scoop): `scoop install sops`

## 3) Generate age key pair
```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

## 4) Show your public key
```bash
age-keygen -y ~/.config/sops/age/keys.txt
```
- Share only the `age1...` public key.
- Never share `AGE-SECRET-KEY-...`.

## 5) Update `.sops.yaml`
1. Add team public keys under `age:`.
2. Rules already cover `.env`, `.env.dev`, `.env.prod`, and `.enc` variants.
3. Apply recipient updates to encrypted files using `updatekeys`.

## 6) Encrypt `.env` files
```bash
sops encrypt --input-type dotenv --output-type dotenv .env > .env.enc
sops encrypt --input-type dotenv --output-type dotenv .env.dev > .env.dev.enc
sops encrypt --input-type dotenv --output-type dotenv .env.prod > .env.prod.enc
```
- Commit only `.env*.enc`.
- Plaintext `.env*` is ignored by Git.

## 7) Verify decryption
```bash
sops decrypt --filename-override .env .env.enc
```
- Prefer viewing in terminal instead of writing plaintext to disk.

## 8) Open IDE with injected env
```bash
./scripts/open-ide.sh code
./scripts/open-ide.sh cursor
./scripts/open-ide.sh idea
```
- Without IDE arg, auto-detect order is:
  `code -> cursor -> windsurf -> idea -> pycharm -> webstorm -> phpstorm -> goland -> rider -> studio -> nvim -> vim`
- Use a different encrypted file:
```bash
./scripts/open-ide.sh --env-file .env.dev.enc
```

## 9) Run any command with injected env
```bash
./scripts/run-with-env.sh npm run dev
./scripts/run-with-env.sh --env-file .env.prod.enc -- npm run start
```

## 10) Supported IDE/editor commands
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

## 11) Add a new teammate (use `updatekeys`)
1. Add the new member public key to `.sops.yaml`.
2. Update recipients in existing encrypted files:
```bash
sops updatekeys .env.enc
sops updatekeys .env.dev.enc
sops updatekeys .env.prod.enc
```
3. Commit `.sops.yaml` and updated `.env*.enc`.

## 12) Remove a teammate (use `rotate`)
1. Remove that member public key from `.sops.yaml`.
2. Rotate data keys (critical for removal):
```bash
sops rotate -i .env.enc
sops rotate -i .env.dev.enc
sops rotate -i .env.prod.enc
```
3. Commit rotated `.env*.enc` and `.sops.yaml`.

## 13) `updatekeys` vs `rotate`
- `updatekeys`: updates recipient metadata; best for member addition.
- `rotate`: re-encrypts with a new data key; required for member removal.

## 14) Enable Git hook
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```
- Default mode (recommended): block commit when plaintext `.env*` is staged.
- Optional mode: `AUTO_ENCRYPT_ENV=1 git commit` auto-refreshes `.env.enc` from `.env`.

## 15) Operational cautions
- Never share private keys.
- Treat `.env*.enc` changes as mandatory review items.
- Run `rotate` immediately when team access changes or key leak is suspected.
- For CI/CD, use dedicated deploy keys, not developer personal keys.
