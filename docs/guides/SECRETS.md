# Secrets Guide

Secrets are encrypted with sops + age and committed to the repo. Plaintext never touches git.

## Why sops + age

`.env` files can't be committed to a public repo. Copying them manually to the VPS means they're lost if the server dies. GitHub Actions secrets (individual variables) are hard to audit and painful to rotate.

sops encrypts the whole file so the ciphertext can be committed; age is the crypto backend — no GPG keyring complexity. Two recipients (laptop + GitHub Actions) means local editing and CI decryption both work independently. Rotating a key is one re-encrypt, not a hunt through GitHub's secrets UI.

## How it works

sops encrypts the entire file as a single blob using age. The ciphertext is stored in a JSON wrapper with sops metadata:

```json
{
  "data": "ENC[AES256_GCM,data:...,type:str]",
  "sops": { "age": [...], "version": "3.12.2" }
}
```

To get per-key encryption (visible key names, meaningful diffs), encrypt with `--input-type dotenv --output-type json` instead.

`.sops.yaml` lists two recipient public keys. sops encrypts once for both — either private key can decrypt.

| Recipient      | Private key location              | Purpose                                                              |
| -------------- | --------------------------------- | -------------------------------------------------------------------- |
| Laptop         | `~/.config/sops/age/keys.txt`     | Local editing, disaster recovery                                     |
| GitHub Actions | `SOPS_AGE_KEY` secret on GitHub   | Deploy-time decryption (injected via SSH, never written to VPS disk) |

During deploy, `deploy.yml` passes the private key over SSH to `deploy_infra.sh` as an env var. sops reads `SOPS_AGE_KEY`, decrypts in memory, and the key is gone when the process exits.

## Install

macOS:

```bash
brew install sops age
```

Debian:

```bash
apt install age
curl -LO https://github.com/getsops/sops/releases/download/v3.12.2/sops_3.12.2_amd64.deb
sudo dpkg -i sops_3.12.2_amd64.deb
rm sops_3.12.2_amd64.deb
```

Generate a key and wire it up:

```bash
age-keygen -o ~/.config/sops/age/keys.txt
echo 'export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt' >> ~/.zshrc
source ~/.zshrc
```

Add the public key to `.sops.yaml` under `creation_rules`.

## Edit a secret

```bash
sops services/postgres/.env.prod.enc
```

Opens in your editor decrypted. Save and close — sops re-encrypts automatically.

## Add a new service

1. Create plaintext `services/<name>/.env.prod` (gitignored)

2. Encrypt it:

   ```bash
   sops --encrypt services/<name>/.env.prod > services/<name>/.env.prod.enc
   ```

3. Add decrypt step to `deploy_infra.sh` (inside the `umask 077` subshell):

   ```bash
   sops --decrypt "${INFRA_DIR}/services/<name>/.env.prod.enc" > "${INFRA_DIR}/services/<name>/.env"
   ```

4. Add the new `.env` path to the validation loop in `deploy_infra.sh`

5. Commit `.env.prod.enc`

## Rotate a key

1. Generate new key: `age-keygen -o ~/.config/sops/age/new.txt`
2. Update `.sops.yaml` — swap old public key for new one
3. Re-encrypt all files in place with the new recipients:

   ```bash
   sops updatekeys services/postgres/.env.prod.enc
   sops updatekeys services/umami/.env.prod.enc
   ```

4. If rotating the GitHub Actions key, update `SOPS_AGE_KEY` secret on GitHub
