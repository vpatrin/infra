# Secrets Management

Secrets are encrypted with [sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) and committed to the repo. Plaintext secrets never touch git.

## How it works

- `.sops.yaml` defines two age recipients: laptop key (DR + local editing) and GitHub Actions key (CD)
- Encrypted files (`.env.prod.enc`) are committed — values are ciphertext, structure is readable
- Plaintext files (`.env`, `.env.prod`) are gitignored

## Setup (one-time, already done)

```bash
brew install sops age
age-keygen -o ~/.config/sops/age/keys.txt
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt  # add to ~/.zshrc
```

## Day-to-day

**Edit a secret:**
```bash
sops services/postgres/.env.prod.enc
# editor opens with decrypted values — save to re-encrypt
```

**Re-encrypt from plaintext (after editing `.env.prod` directly):**
```bash
sops --encrypt services/postgres/.env.prod > services/postgres/.env.prod.enc
```

**Decrypt to inspect:**
```bash
sops --decrypt services/postgres/.env.prod.enc
```

## Rotating keys

1. Generate new age key
2. Add new public key to `.sops.yaml`
3. Remove old public key from `.sops.yaml`
4. Re-encrypt all `.env.prod.enc` files: `sops --encrypt services/postgres/.env.prod > services/postgres/.env.prod.enc`
5. Update GitHub Actions secret `SOPS_AGE_KEY` if rotating the CI key

## Files

| File | Committed | Description |
|------|-----------|-------------|
| `.sops.yaml` | ✅ | age public keys + path rules |
| `services/postgres/.env.prod.enc` | ✅ | encrypted postgres secrets |
| `services/umami/.env.prod.enc` | ✅ | encrypted umami secrets |
| `services/postgres/.env.prod` | ❌ | plaintext (gitignored) |
| `services/umami/.env.prod` | ❌ | plaintext (gitignored) |
| `~/.config/sops/age/keys.txt` | ❌ | laptop private key (never leaves machine) |
| `~/.config/sops/age/github_actions.txt` | ❌ | CI private key (stored in GitHub secrets) |
