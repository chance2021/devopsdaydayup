# Security Policy

## Reporting a Vulnerability

- Please email `security@devopsdaydayup.example` with a clear description of the issue, reproduction steps, affected labs, and any logs or screenshots that help us verify the problem.
- Do not open public issues for suspected security vulnerabilities.
- Avoid sharing real secrets in reports. Use redacted output or safe placeholders.

We aim to acknowledge reports within 5 business days and will keep reporters updated as we validate and address the issue.

## Handling Secrets in Labs

- Never commit real tokens, passwords, private keys, unseal keys, or hostnames that point to internal systems.
- Use placeholders such as `YOUR_GITHUB_TOKEN`, `YOUR_VAULT_ADDR`, and `example.com`.
- Prefer environment variables, `.env` files (ignored by Git), or secret managers for local testing.
- Rotate any test credentials after each lab run.
