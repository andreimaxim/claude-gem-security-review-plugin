#!/usr/bin/env ruby
# One explicitly requested paid session. No retries and no implicit model matrix.
require "json"
require "digest"
require "base64"
require "fileutils"
require "tmpdir"
require "open3"
require "time"
require_relative "sandbox"
require_relative "research_trace"

package, case_id, output = ARGV
abort "Usage: ruby evals/run.rb PACKAGE CASE_ID NEW_OUTPUT_DIRECTORY" unless ARGV.length == 3
package = File.expand_path(package)
output = File.expand_path(output)
abort "Refusing to overwrite #{output}" if File.exist?(output)
manifest = JSON.parse(File.read(File.join(package, "manifest.json")))
item = manifest.fetch("cases").find { |entry| entry["id"] == case_id }
abort "Unknown case: #{case_id}" unless item
abort "Freeze verification failed" unless system("ruby", File.join(__dir__, "verify.rb"), out: File::NULL)
abort "Package belongs to another freeze" unless manifest.fetch("freeze_sha256") == Digest::SHA256.file(File.join(__dir__, "freeze.json")).hexdigest
snapshot = File.join(package, "application.tar")
abort "Snapshot changed" unless Digest::SHA256.file(snapshot).hexdigest == manifest.fetch("application_sha256")
plugin = File.realpath(File.join(package, "plugin"))
paths = Dir.glob("#{plugin}/**/*", File::FNM_DOTMATCH)
abort "Plugin contains symlinks" if paths.any? { |path| File.symlink?(path) }
actual_files = paths.select { |path| File.file?(path) }.map { |path| path.delete_prefix(plugin + "/") }.sort
abort "Unexpected plugin files" unless actual_files == manifest.fetch("plugin_files").keys.sort
manifest.fetch("plugin_files").each do |path, hash|
  abort "Unsafe plugin path" if path.start_with?("/") || path.split("/").include?("..")
  abort "Plugin changed: #{path}" unless Digest::SHA256.file(File.join(plugin, path)).hexdigest == hash
end
runtime = File.realpath(File.expand_path(ENV.fetch("CLAUDE_RUNTIME", "~/.local/share/gem-upgrade-cli")))
abort "SDK driver differs from the freeze; rerun setup" unless Digest::SHA256.file(File.join(runtime, "sdk-runner.mjs")).hexdigest == Digest::SHA256.file(File.join(__dir__, "sdk-runner.mjs")).hexdigest
abort "Unexpected SDK version" unless JSON.parse(File.read(File.join(runtime, "node_modules/@anthropic-ai/claude-agent-sdk/package.json"))).fetch("version") == "0.3.296"
version, errors, status = Open3.capture3(File.join(runtime, "node_modules/.bin/claude"), "--version")
abort "Unexpected Claude Code version: #{errors}" unless status.success? && version.strip == "2.1.296 (Claude Code)"
parent = output
suffix = []
until File.exist?(parent)
  suffix.unshift(File.basename(parent))
  parent = File.dirname(parent)
end
output = File.join(File.realpath(parent), *suffix)
abort "Output must be outside worker mounts" if [plugin, runtime].any? { |path| output == path || output.start_with?(path + "/") }
FileUtils.mkdir_p(output)
sessions = File.join(output, "sessions")
FileUtils.mkdir_p(sessions)
File.write(File.join(output, "request.json"), JSON.pretty_generate(item) + "\n")
FileUtils.cp(File.join(package, "manifest.json"), File.join(output, "manifest.json"))
command = ["/usr/bin/env", "node", "/opt/claude/sdk-runner.mjs"]
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
state = { "started_at" => Time.now.utc.iso8601, "command" => command, "status" => "execution_failure", "isolation" => "bubblewrap; no host checkout or HOME mount" }
begin
  Dir.mktmpdir("notebook-worker-") do |app|
    abort "Extraction failed" unless system("tar", "-xf", snapshot, "-C", app)
    isolated = WorkerSandbox.command(app: app, plugin: plugin, runtime: runtime, sessions: sessions, arguments: command)
    File.open(File.join(output, "trace.jsonl"), "wx") do |trace|
      File.open(File.join(output, "stderr.log"), "wx") do |errors|
        Open3.popen3(WorkerSandbox.environment, *isolated, unsetenv_others: true, pgroup: true) do |input, stream, error_stream, wait|
          drain = Thread.new { IO.copy_stream(error_stream, errors) }
          upgrade = item.fetch("request")
          request = { type: "user", parent_tool_use_id: nil, message: { role: "user", content: "Research the application impact of upgrading #{upgrade.fetch('gem')} from #{upgrade.fetch('currentVersion')} to #{upgrade.fetch('requestedVersion')}. Use the gem-upgrade research tool once and wait for its report." } }
          input.puts(JSON.generate(request))
          input.flush
          research = ResearchTrace.new(item.fetch("request"))
          buffer = +""
          deadline = started + 900
          begin
            loop do
              remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
              raise "Session timed out after 900 seconds" if remaining <= 0
              next unless IO.select([stream], nil, nil, remaining)
              chunk = stream.read_nonblock(65536, exception: false)
              break if chunk.nil?
              next if chunk == :wait_readable
              buffer << chunk
              while (newline = buffer.index("\n"))
                line = buffer.slice!(0, newline + 1)
                trace.write(line)
                trace.flush
                event = JSON.parse(line)
                if event["type"] == "eval_session_log"
                  path = event.fetch("path")
                  raise "Unsafe transcript path" if path.start_with?("/") || path.split("/").include?("..")
                  destination = File.join(output, "sessions", path)
                  FileUtils.mkdir_p(File.dirname(destination))
                  File.binwrite(destination, Base64.strict_decode64(event.fetch("data")))
                end
                research.observe(event)
                input.close if research.handoff? && !input.closed?
              end
            end
            trace.write(buffer) unless buffer.empty?
            raise "Session did not exit before deadline" unless wait.join([deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max)
            status = wait.value
            drain.join
            state["exit_code"] = status.exitstatus
            state["worker_id"] = research.worker_id
            state["worker_completed"] = !research.report.nil?
            state["main_handoff"] = !!research.handoff?
            state["status"] = "completed" if status.success? && research.report && research.handoff?
          ensure
            input.close unless input.closed?
            if wait.alive?
              Process.kill("TERM", -wait.pid)
              Process.kill("KILL", -wait.pid) unless wait.join(2)
            end
            drain.join
          end
        end
      end
    end
  end
rescue StandardError => error
  state["error"] = "#{error.class}: #{error.message}"
ensure
  state["duration_seconds"] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  File.write(File.join(output, "execution.json"), JSON.pretty_generate(state) + "\n")
end
puts JSON.pretty_generate(state)
exit(state["status"] == "completed" ? 0 : 1)
