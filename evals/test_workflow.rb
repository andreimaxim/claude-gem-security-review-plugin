#!/usr/bin/env ruby
# Public workflow invariants; no paid sessions or model correctness assertions.
require "json"
require "digest"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "sandbox"
root = File.expand_path("..", __dir__)
abort "Usage: ruby evals/test_workflow.rb APP_DIRECTORY" unless ARGV.length == 1
application = File.expand_path(ARGV.first)
runtime = File.expand_path(ENV.fetch("CLAUDE_RUNTIME", "~/.local/share/gem-upgrade-cli"))
def assert(condition, message)
  abort message unless condition
end

Dir.mktmpdir("notebook-harness-") do |dir|
  packages = %w[first second].map { |name| File.join(dir, name) }
  packages.each do |path|
    assert(system("ruby", File.join(__dir__, "prepare.rb"), application, path), "Preparation failed")
  end
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "prepare.rb"), application, packages.first)
  assert(!status.success?, "Existing preparation overwritten")
  hashes = packages.map { |path| Digest::SHA256.file(File.join(path, "application.tar")).hexdigest }
  assert(hashes.uniq.one?, "Application snapshot is not deterministic")
  out, _errors, status = Open3.capture3("tar", "-tf", File.join(packages.first, "application.tar"))
  names = out.lines.map(&:strip)
  assert(status.success? && names.include?("Gemfile.lock") && names.include?("app/models/note.rb"), "Missing working app files")
  assert(names.none? { |name| name.match?(/eval|rubric|answer|evidence|\.git(?:\/|\z)|\.sqlite3/) }, "Evaluator data leaked into snapshot")

  app = File.join(dir, "app")
  FileUtils.mkdir_p(app)
  assert(system("tar", "-xf", File.join(packages.first, "application.tar"), "-C", app), "Extraction failed")
  # Probe the exact runner namespace, including known absolute host paths and
  # /proc/1/root. Tool access cannot make an absent filesystem mount visible.
  command = WorkerSandbox.command(app: app, plugin: File.join(packages.first, "plugin"), runtime: runtime,
    arguments: ["/bin/sh", "-c", 'test -r /app/Gemfile && test -r /plugin/hooks/register.ts && ! test -e "$1" && ! test -e /app/../evals && ! test -e /proc/1/root/home/user/workspace/repo/evals/answer_key.rb && ! touch /app/worker-write && echo CONTAINED', "sh", File.join(root, "evals/answer_key.rb")])
  out, errors, status = Open3.capture3({}, *command, unsetenv_others: true)
  assert(status.success? && out.include?("CONTAINED"), "Filesystem containment failed: #{errors}")
  cli = WorkerSandbox.command(app: app, plugin: File.join(packages.first, "plugin"), runtime: runtime,
    arguments: ["/opt/claude/node_modules/.bin/claude", "--version"])
  out, errors, status = Open3.capture3({}, *cli, unsetenv_others: true)
  assert(status.success? && out.include?("2.1.296"), "Isolated CLI failed: #{errors}")

  # Exercise the real runner's streaming lifecycle with a protocol peer, not a
  # model. An early stdin close fails; after the follow-up, EOF is required.
  fake_runtime = File.join(dir, "protocol-peer")
  executable = File.join(fake_runtime, "node_modules/.bin/claude")
  FileUtils.mkdir_p(File.dirname(executable))
  File.write(executable, <<~SH)
    #!/bin/bash
    read -r request || exit 2
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"call-1","name":"mcp__gem-upgrade__research","input":{"gem":"rails","currentVersion":"7.0.8.7","requestedVersion":"8.1.4"}}]}}'
    echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"call-1","content":"Research started for rails 7.0.8.7 → 8.1.4 (agent worker-1)."}]}}'
    echo '{"type":"result","result_index":0,"is_error":false}'
    read -r -t 0.05 unexpected
    code=$?
    (( code > 128 )) || exit 3
    echo '{"type":"result","result_index":1,"is_error":false}'
    echo '{"subtype":"task_notification","task_id":"worker-1","status":"completed","summary":"report"}'
    read -r after && exit 4
    exit 0
  SH
  File.chmod(0o755, executable)
  out, errors, status = Open3.capture3({"CLAUDE_RUNTIME" => fake_runtime}, "ruby", File.join(__dir__, "run.rb"), packages.first, "rails", File.join(dir, "protocol-run"))
  assert(status.success? && JSON.parse(out)["main_handoff"], "Persistent-input handoff failed: #{out}\n#{errors}")

  run = File.join(dir, "trace-test")
  FileUtils.mkdir_p(run)
  manifest = JSON.parse(File.read(File.join(packages.first, "manifest.json")))
  item = manifest.fetch("cases").find { |entry| entry["id"] == "activesupport" }
  FileUtils.cp(File.join(packages.first, "manifest.json"), File.join(run, "manifest.json"))
  File.write(File.join(run, "request.json"), JSON.generate(item))
  tool = { "type" => "assistant", "message" => { "content" => [{ "type" => "tool_use", "id" => "call-1", "name" => "mcp__gem-upgrade__research", "input" => item.fetch("request") }] } }
  acknowledgement = {"type" => "user", "message" => {"content" => [{"type" => "tool_result", "tool_use_id" => "call-1", "content" => "Research started for activesupport 7.0.8.7 → 8.1.4 (agent worker-1)."}]}}
  events = [tool, tool, {"type" => "result", "total_cost_usd" => 1},
            acknowledgement,
            {"subtype" => "task_notification", "task_id" => "worker-1", "status" => "completed", "summary" => "Source-linked report"},
            {"subtype" => "task_notification", "task_id" => "unrelated-worker", "status" => "completed", "summary" => "Unrelated report"},
            {"type" => "result", "result_index" => 1, "total_cost_usd" => 3}]
  File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
  File.write(File.join(run, "stderr.log"), "")
  File.write(File.join(run, "execution.json"), JSON.generate("status" => "completed"))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
  assert(status.success?, "Trace summarization failed")
  summary = JSON.parse(File.read(File.join(run, "summary.json")))
  assert(summary["research_dispatches"] == 1 && summary.dig("final_usage_record", "total_cost_usd") == 3, "Repeated stream events double-counted")
  assert(File.read(File.join(run, "report.txt")) == "Source-linked report", "Unrelated worker report selected")
  require_relative "answer_key"
  findings = ANSWER_KEY["issues"].select { |issue| issue["gem"] == "activesupport" }.map do |issue|
    {"id" => issue["id"], "status" => "omitted", "quote" => "", "reason" => "Absent in protocol fixture",
      "sources" => ["https://raw.githubusercontent.com/rails/rails/v8.1.4/#{issue['source']}"]}
  end
  findings.first.merge!("status" => "found", "quote" => "Source-linked report", "reason" => "Protocol fixture; not a semantic correctness assertion")
  review = { "report_sha256" => summary["report_sha256"], "false_claims" => [], "findings" => findings }
  review_path = File.join(dir, "review.json")
  File.write(review_path, JSON.generate(review))
  _out, errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(status.success?, "Valid review rejected: #{errors}")
  File.write(File.join(run, "report.txt"), "replacement report")
  review["report_sha256"] = Digest::SHA256.hexdigest("replacement report")
  File.write(review_path, JSON.generate(review))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(!status.success?, "Replacement report accepted with a new review hash")
  File.write(File.join(run, "report.txt"), "Source-linked report")
  review["report_sha256"] = summary["report_sha256"]
  review["findings"].first["quote"] = "not present in report"
  File.write(review_path, JSON.generate(review))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(!status.success?, "Fabricated quote accepted")
  review["findings"].first["status"] = "uncertain"
  File.write(review_path, JSON.generate(review))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(!status.success?, "Fabricated uncertain quote accepted")

  # Mutate only a disposable evaluator copy; an unchanged freeze must not bless
  # changed rubric content when grading a trial from the frozen revision.
  copied_eval = File.join(dir, "evals")
  FileUtils.cp_r(File.join(root, "evals"), copied_eval)
  JSON.parse(File.read(File.join(__dir__, "freeze.json"))).keys.reject { |path| path.start_with?("evals/") }.each do |path|
    target = File.join(dir, path)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(File.join(root, path), target)
  end
  File.open(File.join(copied_eval, "answer_key.rb"), "a") { |file| file.puts("# changed after trial") }
  review["findings"].first.merge!("status" => "found", "quote" => "Source-linked report")
  File.write(review_path, JSON.generate(review))
  _out, errors, status = Open3.capture3("ruby", File.join(copied_eval, "grade.rb"), run, review_path)
  assert(!status.success? && errors.include?("Freeze changed:"), "Grading accepted modified rubric with unchanged freeze")
end
puts "PASS: deterministic answer-free snapshot, overwrite rejection, real namespace containment, isolated CLI, streaming handoff, trace deduplication, final usage record and review validation. No paid sessions."
