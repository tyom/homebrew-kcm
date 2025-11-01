# Security Policy

## Reporting a Vulnerability

We take security seriously. If you discover a vulnerability, please report it responsibly.

**DO NOT** create a public GitHub issue. Send details privately including:

- Description and steps to reproduce
- Potential impact
- Suggested fix (if available)

**Response**: Acknowledgment within 48 hours, regular updates, and credit in fix announcement.

## Security Best Practices

### For Users

1. **Review untrusted .env files** before use
2. **Use --allow-unsafe carefully** - only with trusted sources
3. **Enable FileVault** and use a strong macOS password
4. **Rotate secrets periodically**

### For Development

1. **Never commit secrets** - add `.env` to `.gitignore`
2. **Use environment-specific files** - separate dev/prod
3. **Document required secrets** - use `.env.example` with dummy values

## Known Limitations

### Keychain Access Control

**Critical**: Keychain items created by kcm are accessible to any process running under your user account. This is how macOS Keychain works with CLI tools.

**Any process you run can access these secrets**, including:

- Applications and scripts
- Processes with your user privileges
- Malware running under your account

**This is by design** - macOS assumes processes running as you have your authority.

### When to Use KCM

**Appropriate:**

- Development secrets
- Local testing credentials
- Non-critical API keys
- Replacing plain text storage

**NOT appropriate:**

- Production credentials
- Highly sensitive data
- Shared/multi-user systems
- High-security environments

### Security Comparison

**Better than:**

- AWS CLI (plain text `~/.aws/credentials`)
- Docker (plain text `~/.docker/config.json`)
- npm/yarn (plain text `.npmrc`)
- Git credential storage

**Less secure than:**

- 1Password CLI (separate encrypted vault)
- HashiCorp Vault (fine-grained access control)
- App-specific keychain items (ACLs)

### Other Limitations

**Process Arguments**: Secret values briefly appear in process arguments when added to keychain (milliseconds, local access required).

**Memory Storage**: Secrets in environment variables remain in process memory and could be swapped to disk. Use FileVault.

### Additional Mitigations

If you need more security:

1. Use a dedicated macOS user account for sensitive work
2. Enable monitoring tools (Santa, Objective-See)
3. Audit keychain access: `security dump-keychain | grep "acct"`
4. Use 1Password CLI for highly sensitive secrets

## Security Features

- Input validation (key names, variable names, values, paths)
- Safe parsing without `eval` or `source`
- Dangerous characters blocked by default (`$`, `` ` ``, `;`, `|`, `&`, `\`)
- System files rejected (`/etc/passwd`, etc.)
- Clipboard auto-clear (45 seconds, immediate on interruption)
- Secure temporary files (`mktemp`)

## Security Checklist for Contributors

Before submitting PRs:

- Run tests: `./test_kcm.sh`
- Run ShellCheck: `shellcheck kcm`
- Review for injection vulnerabilities
- Validate all user input
- Test with malformed input
- Document security considerations

---

_For technical architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md)._
