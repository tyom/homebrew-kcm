# Release Process

## Local Release (Developer)

```bash
./release.sh 0.5.0
```

**What happens:**
1. Updates version in `kcm` script (lines 3 & 9)
2. Commits `kcm` with message "Release v0.5.0"
3. Creates annotated tag `v0.5.0`
4. Pushes commit + tag to `origin main`

**Result:** Tag push triggers GitHub Actions workflow

## CI Release (Automated)

Triggered by tag push (`v*`)

**Test job:**
- Runs `test_kcm.sh` on macOS

**Release job** (after tests pass):
1. Downloads GitHub's release tarball
2. Calculates SHA256 from tarball
3. Generates `Formula/kcm.rb` from template with version + SHA256
4. Commits `Formula/kcm.rb` to main
5. Pushes to main
6. Creates GitHub release with install instructions

## Dry Run

```bash
./release.sh --dry-run 0.5.0
```

Shows what would happen without making changes.

## Notes

- `kcm` version updated locally before tag
- `Formula/kcm.rb` generated in CI from GitHub's actual tarball
- Ensures Homebrew formula SHA256 matches GitHub's release tarball
