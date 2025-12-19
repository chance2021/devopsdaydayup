# Contributing Guide

Thanks for helping improve the DevOpsDaydayup labs! This guide explains how to propose changes while keeping the labs secure, reproducible, and beginner-friendly.

## How to Contribute

- **Before you start**: Browse open issues and existing labs to avoid duplication. If you are unsure, open a short issue describing your idea.
- **Fork and branch**: Use a feature branch per change set. Keep pull requests small and focused.
- **Follow the lab template**: Each lab should include Title, Overview, Prerequisites, Architecture/Diagram (if useful), Setup, Step-by-step instructions, Validation, Cleanup, Troubleshooting, and References.
- **Keep labs runnable**: Test every command. Prefer pinned versions (images, Helm charts, binaries) and note the tested environment (OS, CPU/RAM).
- **Use placeholders for secrets**: Never commit real tokens, passwords, keys, hostnames, or IPs. Use placeholders like `YOUR_GITHUB_TOKEN`, `example.com`, or `0000000000000000`. Recommend storing secrets in environment variables or secret managers.
- **Document verification**: Add simple validation steps (e.g., `kubectl get pods`, curl endpoints, or screenshot descriptions) so readers can confirm success.
- **Style**: Use clear, concise Markdown. Prefer ordered steps. Add brief context before code blocks and keep long commands copy-pasteable.

## Submitting Changes

1. Run or lint your changes locally when applicable.
2. Update relevant README files and diagrams.
3. Add tests or validation steps if you change behavior.
4. Describe what changed and why in your pull request. Mention any known limitations.

## Community Standards

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). For security issues, please follow the process in [SECURITY.md](SECURITY.md).
