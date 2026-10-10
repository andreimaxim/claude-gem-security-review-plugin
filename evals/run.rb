#!/usr/bin/env ruby
# One explicitly requested paid session. No retries and no implicit model matrix.
require "json"
require "digest"
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
parent = output
suffix = []
until File.exist?(parent)
  suffix.unshift(File.basename(parent))
  parent = File.dirname(parent)
end
output = File.join(File.realpath(parent), *suffix)
abort "Output must be outside worker mounts" if [plugin, runtime].any? { |path| output == path || output.start_with?(path + "/") }
FileUtils.mkdir_p(output)
File.write(File.join(output, "request.json"), JSON.pretty_generate(item) + "\n")
FileUtils.cp(File.join(package, "manifest.json"), File.join(output, "manifest.json"))
command = ["/opt/claude/node_modules/.bin/claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
           "--plugin-dir", "/plugin", "--setting-sources", "", "--model", "claude-opus-5-5",
           "--permission-mode", "dontAsk", "--tools", "Read,Glob,Grep,WebSearch,WebFetch,Agent,ToolSearch",
           "--allowedTools", "Read,Glob,Grep,WebSearch,WebFetch,mcp__gem-upgrade__research",
           "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}', "--disable-slash-commands",
           "--forward-subagent-text", "--include-hook-events"]
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
state = { "started_at" => Time.now.utc.iso8601, "command" => command, "status" => "execution_failure", "isolation" => "bubblewrap; no host checkout or HOME mount" }
begin
  Dir.mktmpdir("notebook-worker-") do |app|
    abort "Extraction failed" unless system("tar", "-xf", snapshot, "-C", app)
    isolated = WorkerSandbox.command(app: app, plugin: plugin, runtime: runtime, arguments: command)
    File.open(File.join(output, "trace.jsonl"), "wx") do |trace|
      File.open(File.join(output, "stderr.log"), "wx") do |errors|
        Open3.popen3(WorkerSandbox.environment, *isolated, unsetenv_others: true, pgroup: true) do |input, stream, error_stream, wait|
          drain = Thread.new { IO.copy_stream(error_stream, errors) }
          request = { type: "user", parent_tool_use_id: nil, message: { role: "user", content: "Use the gem-upgrade research tool exactly once for #{JSON.generate(item.fetch('request'))}. Wait for its completed report, then summarize it. Do not research independently, retry, or modify files." } }
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
