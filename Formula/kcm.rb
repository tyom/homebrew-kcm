class Kcm < Formula
  desc "Keychain Master - Secure secret management for macOS"
  homepage "https://github.com/tyom/kcm"
  url "https://github.com/tyom/kcm/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "1f38bf9805ff219bdf2f01c04cc156c5be858a6e68579254b756a8080b292b85"
  license "MIT"

  depends_on :macos
  depends_on "bash"

  def install
    # Install the script
    bin.install "kcm"
    chmod 0755, bin/"kcm"

    # Update shebang to use brew's bash
    inreplace bin/"kcm", "#!/usr/bin/env bash", "#!#{Formula["bash"].opt_bin}/bash"
  end

  test do
    # Test help command
    assert_match "Keychain Master", shell_output("#{bin}/kcm help")

    # Test that the script exists and is executable
    assert_predicate bin/"kcm", :exist?
    assert_predicate bin/"kcm", :executable?

    # Test version command
    assert_match(/kcm version \d+\.\d+\.\d+/, shell_output("#{bin}/kcm version"))

    # Test that the script can run without errors
    # Avoid keychain operations that might trigger GUI prompts in CI
    system "#{bin}/kcm", "help"
  end

  def caveats
    <<~EOS
      kcm has been installed! Here's how to get started:

      1. Add a secret to your Keychain:
         kcm add DATABASE_URL "your-connection-string"

      2. Add the reference to your .env file:
         DATABASE_URL="keychain://DATABASE_URL"

      3. Run your application with resolved secrets:
         kcm use -- npm run dev

      For more information:
         kcm help
    EOS
  end
end