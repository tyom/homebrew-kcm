# KCM Architecture

Technical overview of KCM's design and implementation decisions.

## Design Philosophy

### Security by Default

Input validation, no `eval` or `source`, dangerous patterns blocked unless explicitly allowed.

### Developer Experience

Simple commands, works with existing `.env` workflows, clear error messages.

### Single-File Distribution

One bash script, no external dependencies, easy to audit.

### macOS-First

Leverages native Keychain via the `security` command.

## Core Architecture

### Command Flow

```
User Input → Validation → Keychain Operation → Output
```

All commands follow this pattern with appropriate validation at each step.

### Secret Storage

Secrets are stored as generic password entries in the macOS login keychain using `security add-generic-password`. The service name is the environment variable name (e.g., `API_KEY`).

### Environment Resolution

The `use` command:

1. Parses `.env` files line-by-line (never using `eval`)
2. Resolves `keychain://` references by querying the keychain
3. Validates all values against a security filter
4. Exports variables and executes the user command via `exec`

## Security Architecture

### Four Validation Layers

1. **Key Names**: Must match `^[A-Za-z][A-Za-z0-9_]*$`
2. **Variable Names**: Must be valid shell identifiers
3. **Values**: Block `$()`, `` ` ``, `$`, `;`, `|`, `&`, `\` by default
4. **Paths**: Prevent access to system files like `/etc/passwd`

### Safe Parsing

Environment files are parsed manually without shell interpretation:

- Split on first `=` only
- Store in arrays before exporting
- Validate before execution
- No code evaluation

### Cleanup on Exit

Signal handlers ensure:

- Clipboard is cleared immediately on interruption
- Background jobs are terminated
- No secrets persist after exit

## Key Design Decisions

### Why Bash?

Universal on macOS, direct access to system commands, simple distribution. The single-file constraint outweighs language limitations.

### Why Generic Keychain Items?

The CLI `security` command doesn't support app-specific ACLs. This trades fine-grained access control for simplicity and CLI compatibility.

### Why Not Custom Encryption?

macOS Keychain provides OS-managed encryption, system authentication, and battle-tested security. Following "don't roll your own crypto."

### Why 45 Seconds for Clipboard?

Balances usability (enough time to paste) with security (minimal exposure). Empirically sufficient for normal workflows.

### Why `exec` for Command Execution?

Replaces the script process with the target command, ensuring:

- Correct signal propagation
- No lingering process in memory
- Clean process tree

## Implementation Patterns

### Keychain Operations

All keychain interactions go through wrapper functions that handle errors gracefully and provide consistent behavior.

### Environment Processing

Uses parallel arrays (`PROCESSED_ENV_NAMES`, `PROCESSED_ENV_VALUES`) to validate everything before exporting anything. Atomic environment setup.

### Pattern Matching

Converts shell wildcards to regex and uses a two-phase filter:

1. Pattern match during keychain parsing
2. Accessibility check for each candidate

### Error Handling

Strict mode (`set -euo pipefail`) with explicit error handling for user-facing operations. Errors include helpful messages and exit codes.

## Trade-offs

### Security vs. Usability

- **Strict by default**: Special characters blocked to prevent injection
- **Escape hatch**: `--allow-unsafe` flag for legitimate use cases
- Favors security while acknowledging real-world needs

### Simplicity vs. Features

- **No folders/tags**: Use naming conventions (e.g., `PROD_API_KEY`)
- **No rotation tracking**: External workflow
- **No multi-user**: Per-user keychain model
- Keeps the tool focused and maintainable

### Access Control vs. CLI Compatibility

- **Generic keychain items**: Any process can access
- **Better than alternatives**: Still encrypted, better than plain text
- **Clear documentation**: Users understand the security model
- Appropriate for development secrets, not production credentials

## Performance Characteristics

### Bottlenecks

- Keychain operations: ~50-100ms per `security` command
- File I/O: Negligible for typical `.env` files
- Process spawning: Minimized through native bash features

### Optimizations

- Batch operations where possible
- Single keychain dump for listing
- Native pattern matching over external commands
- No lingering parent process after `exec`

## Testing Strategy

Tests are organized into functional groups (basic commands, validation, security, edge cases) with isolated execution. Each test uses unique identifiers and cleanup ensures no artifacts remain.

Helper assertions (`assert_equals`, `assert_contains`, `assert_exit_code`) provide clear failure messages.

## Future Considerations

### Potential Enhancements

- Secret expiration/rotation metadata
- Integration with other secret backends (abstraction layer)
- Optional audit logging
- Native macOS app for better ACL support

### Explicit Non-Goals

- Cross-platform support (macOS-specific by design)
- Complex organization (naming conventions suffice)
- Secret generation (dedicated tools exist)
- Multi-user secrets (per-user model)

## File Structure

```
kcm                  # Main executable (single file)
test_kcm.sh          # Test suite
SECURITY.md          # User-facing security policy
ARCHITECTURE.md      # This document
README.md            # User documentation
```

All functionality is in the single `kcm` script for easy distribution and auditing.

---

For security policy and vulnerability reporting, see [SECURITY.md](SECURITY.md).
