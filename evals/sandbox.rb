# Linux read-only application/plugin mounts for the SDK runner.
# The evaluator repository, host HOME, /tmp and process namespace are NOT mounted.
module WorkerSandbox
  def self.command(app:, plugin:, runtime:, sessions:, arguments:)
    command = ["bwrap", "--unshare-all", "--share-net", "--die-with-parent", "--new-session"]
    %w[/usr /lib /lib64].each { |path| command += ["--ro-bind", path, path] if File.directory?(path) }
    command += ["--symlink", "usr/bin", "/bin", "--symlink", "usr/sbin", "/sbin",
                "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp",
                "--dir", "/home", "--dir", "/home/worker", "--dir", "/etc",
                "--dir", "/home/worker/.claude",
                "--bind", sessions, "/home/worker/.claude/projects",
                "--ro-bind", "/etc/ssl/certs", "/etc/ssl/certs",
                "--ro-bind", "/etc/resolv.conf", "/etc/resolv.conf",
                "--ro-bind", app, "/app", "--ro-bind", plugin, "/plugin",
                "--ro-bind", runtime, "/opt/claude",
                "--setenv", "HOME", "/home/worker",
                "--setenv", "PATH", "/usr/local/bin:/usr/bin:/bin",
                "--chdir", "/app", "--"]
    command + arguments
  end

  def self.environment
    # Forward only explicit provider authentication/proxy settings, not the
    # evaluator's environment or global effort overrides. Never log values.
    %w[ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN HTTPS_PROXY HTTP_PROXY ALL_PROXY NO_PROXY].to_h { |name| [name, ENV[name]] }.compact
  end
end
