# KCM - Keychain Master

A secure command-line utility for managing secrets in macOS Keychain with seamless `.env` file integration.

## Features

- **Secure Storage**: Store sensitive data in macOS Keychain instead of plain text files
- **Environment Integration**: Seamlessly resolve `keychain://` placeholders in `.env` files
- **Clipboard Management**: Copy secrets to clipboard with automatic clearing after 45 seconds
- **Pattern Matching**: List and search secrets using wildcards
- **Simple CLI**: Intuitive commands for adding, removing, and managing secrets
- **Zero Dependencies**: Pure bash script using native macOS security tools

## Installation

### Using Homebrew

```bash
# Add the tap
brew tap tyom/kcm

# Install kcm
brew install kcm
```

### Manual Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/tyom/homebrew-kcm/main/kcm

# Make it executable
chmod +x kcm

# Move to your PATH
sudo mv kcm /usr/local/bin/
```

## Usage

### Adding Secrets

Add a secret to the Keychain and get the `.env` entry:

```bash
# Interactive mode (prompts for value)
kcm add DATABASE_URL

# Direct value
kcm add API_KEY "sk-abc123def456"

# From stdin
echo "secret-value" | kcm add TOKEN -
cat ~/secret-file.txt | kcm add AWS_SECRET -
```

After adding, you'll get a `.env` entry like:

```
DATABASE_URL="keychain://DATABASE_URL"
```

### Using Secrets in Applications

Run any command with secrets from your `.env` file automatically resolved:

```bash
# Use default .env file
kcm use -- npm run dev

# Specify a custom env file
kcm use --env-file .env.production -- node server.js

# Access resolved variables in scripts
kcm use -- bash -c 'echo $DATABASE_URL'
```

### Managing Secrets

```bash
# Show a secret value
kcm show DATABASE_URL

# Copy to clipboard (auto-clears after 45 seconds)
kcm copy API_KEY

# List all secrets
kcm ls

# List secrets matching a pattern
kcm ls "DATABASE*"
kcm ls "*_KEY"

# Remove a secret
kcm remove OLD_API_KEY
```

## Environment File Format

Your `.env` files can use the special `keychain://` prefix to reference Keychain secrets:

```env
# .env example
DATABASE_URL="keychain://DATABASE_URL"
API_KEY="keychain://API_KEY"
REDIS_URL="keychain://REDIS_URL"

# Regular values work too
PORT=3000
NODE_ENV=development
```

When you run `kcm use -- <command>`, all `keychain://` references are automatically resolved from the Keychain.

## Security Benefits

1. **No Plain Text Secrets**: Sensitive data never stored in files
2. **Keychain Protection**: Leverages macOS Keychain's built-in security
3. **Access Control**: Secrets protected by your macOS user account
4. **Audit Trail**: Keychain access can be monitored via Console
5. **Auto-clearing Clipboard**: Copied secrets automatically removed after 45 seconds

## Examples

### Setting Up a New Project

```bash
# Add your database credentials
kcm add DATABASE_URL "postgresql://user:pass@localhost/mydb"

# Add your API keys
kcm add STRIPE_KEY
kcm add SENDGRID_KEY

# Create your .env file
cat > .env << EOF
DATABASE_URL="keychain://DATABASE_URL"
STRIPE_KEY="keychain://STRIPE_KEY"
SENDGRID_KEY="keychain://SENDGRID_KEY"
PORT=3000
EOF

# Run your application
kcm use -- npm run dev
```

### CI/CD Integration

```bash
# Store deployment credentials
kcm add AWS_ACCESS_KEY_ID
kcm add AWS_SECRET_ACCESS_KEY

# Deploy script
kcm use --env-file .env.deploy -- ./deploy.sh
```

### Team Collaboration

Share `.env` files with `keychain://` placeholders in your repository. Each team member stores their own credentials locally:

```bash
# Team member setup
git clone https://github.com/yourteam/project
cd project

# Each member adds their own credentials
kcm add DATABASE_URL  # Enter their dev database URL
kcm add API_KEY        # Enter their personal API key

# Everyone can now run the app with their own credentials
kcm use -- npm start
```

## Requirements

- macOS (uses native `security` command)
- Bash 4.0 or higher
- Access to macOS Keychain

## Important Notes

### macOS Security Prompts

When using kcm for the first time or accessing certain secrets, **macOS will display a security dialog** asking for your password or Touch ID. This is normal behavior - macOS is protecting your Keychain and requires your authorization to allow kcm to access stored secrets.

You may see prompts like:

- "kcm wants to use your confidential information stored in [KEY_NAME] in your keychain"
- You can click "Always Allow" to avoid repeated prompts for the same secret

## Troubleshooting

### Permission Issues

If you encounter permission errors, ensure you have access to the login keychain:

```bash
security list-keychains
```

### Viewing Keychain Entries

You can verify entries directly using macOS security command:

```bash
security find-generic-password -s "YOUR_KEY_NAME" -w
```

### Clearing Stuck Secrets

If a secret seems stuck or corrupted:

```bash
# Remove using kcm
kcm remove KEY_NAME

# Or remove directly via security command
security delete-generic-password -s "KEY_NAME"
```

## Development

### Release Process

To create a new release:

1. **Test with dry-run first:**

   ```bash
   ./release.sh --dry-run 0.2.0
   ```

   This shows what will happen without making any changes.

2. **Create the actual release:**

   ```bash
   ./release.sh 0.2.0
   ```

   This will:

   - Update version in the kcm script
   - Generate Formula/kcm.rb from template
   - Commit and create a git tag
   - Push to GitHub
   - Calculate SHA256 for the release tarball
   - Update the formula with the correct SHA256
   - Push the final formula

3. **Users can then upgrade:**
   ```bash
   brew upgrade kcm
   ```

The release script handles all versioning, tagging, and formula updates automatically.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Author

Created by Tyom Semonov

## Acknowledgments

Built with ♥︎ using native macOS security tools for maximum compatibility and security.
