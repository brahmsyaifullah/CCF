class Ccf < Formula
  desc "Claude Code Fusion — multi-model panel inside Claude Code on your own seats"
  homepage "https://github.com/brahmsyaifullah/CCF"
  url "https://github.com/brahmsyaifullah/CCF/archive/refs/tags/v1.3.0.tar.gz"
  sha256 "793b5b26755a1bdfe124ac67795a81d0b29ee2f25a4bbbfc0667b7849463f60d"
  license "MIT"
  version "1.3.0"

  depends_on "jq"
  depends_on "curl" => :recommended

  def install
    # CCF installs into the user's ~/.claude (config + hooks), not the Homebrew prefix.
    # Stage the repo in libexec and expose a `ccf` wrapper that runs the installer.
    libexec.install Dir["*"]
    (bin/"ccf").write <<~SH
      #!/bin/bash
      # `ccf` -> run the CCF installer (writes to ~/.claude). Pass-through flags supported.
      exec bash "#{libexec}/install.sh" "$@"
    SH
  end

  def caveats
    <<~EOS
      CCF ships as a Claude Code extension that installs into ~/.claude.
      Finish setup by running:

        ccf

      Then add your API keys (`~/.claude/fusion/fusion-onboard`) and restart Claude Code.
      Update later with `/ccf-update` inside Claude Code, or `brew upgrade ccf`.
    EOS
  end

  test do
    assert_predicate libexec/"bin/fusion-call", :exist?
    assert_match "CCF", shell_output("#{bin}/ccf --help 2>&1")
  end
end
