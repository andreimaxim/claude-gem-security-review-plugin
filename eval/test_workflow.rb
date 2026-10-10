#!/usr/bin/env ruby
# Public workflow invariants; no paid sessions or model correctness assertions.
require "json"
require "digest"
require "tmpdir"
require "fileutils"
require "open3"
require_relative "sandbox"
root = File.expand_path("..", __dir__)
runtime = File.expand_path(ENV.fetch("CLAUDE_RUNTIME", "~/.local/share/gem-upgrade-cli"))
def assert(condition, message)
  abort message unless condition
end

Dir.mktmpdir("notebook-harness-") do |dir|
  packages = %w[first second].map { |name| File.join(dir, name) }
  packages.each do |path|
    assert(system("ruby", File.join(__dir__, "prepare.rb"), path), "Preparation failed")
  end
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "prepare.rb"), packages.first)
  assert(!status.success?, "Existing preparation overwritten")
  hashes = packages.map { |path| Digest::SHA256.file(File.join(path, "application.tar")).hexdigest }
  assert(hashes.uniq.one?, "Application snapshot is not deterministic")
  out, _errors, status = Open3.capture3("tar", "-tf", File.join(packages.first, "application.tar"))
  names = out.lines.map(&:strip)
  assert(status.success? && names.include?("Gemfile.lock") && names.include?("app/models/note.rb"), "Missing working app files")
  assert(names.none? { |name| name.match?(/eval|rubric|answer|evidence|\.git|\.sqlite3|migration\.tar/) }, "Evaluator data leaked into snapshot")

  app = File.join(dir, "app")
  FileUtils.mkdir_p(app)
  assert(system("tar", "-xf", File.join(packages.first, "application.tar"), "-C", app), "Extraction failed")
  # Probe the exact runner namespace, including known absolute host paths and
  # /proc/1/root. Tool access cannot make an absent filesystem mount visible.
  command = WorkerSandbox.command(app: app, plugin: File.join(packages.first, "plugin"), runtime: runtime,
    arguments: ["/bin/sh", "-c", 'test -r /app/Gemfile && test -r /plugin/hooks/register.ts && ! test -e "$1" && ! test -e /app/../eval && ! test -e /proc/1/root/home/user/workspace/repo/eval/answer_key.rb && ! touch /app/worker-write && echo CONTAINED', "sh", File.join(root, "eval/answer_key.rb")])
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
    echo '{"type":"result","result_index":0,"is_error":false}'
    read -r -t 0.05 unexpected
    code=$?
    (( code > 128 )) || exit 3
    echo '{"subtype":"task_notification","status":"completed","summary":"report"}'
    echo '{"type":"result","result_index":1,"is_error":false}'
    read -r after && exit 4
    exit 0
  SH
  File.chmod(0o755, executable)
  out, errors, status = Open3.capture3({"CLAUDE_RUNTIME" => fake_runtime}, "ruby", File.join(__dir__, "run.rb"), packages.first, "rails", File.join(dir, "protocol-run"))
  assert(status.success? && JSON.parse(out)["main_handoff"], "Persistent-input handoff failed: #{out}\n#{errors}")

  run = File.join(dir, "trace-test")
  FileUtils.mkdir_p(run)
  tool = { "type" => "assistant", "message" => { "content" => [{ "type" => "tool_use", "id" => "call-1", "name" => "mcp__gem-upgrade__research" }] } }
  events = [tool, tool, {"type" => "result", "total_cost_usd" => 1},
            {"subtype" => "task_notification", "status" => "completed", "summary" => "Source-linked report"},
            {"type" => "result", "total_cost_usd" => 3}]
  File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
  File.write(File.join(run, "stderr.log"), "")
  File.write(File.join(run, "execution.json"), JSON.generate("status" => "completed"))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
  assert(status.success?, "Trace summarization failed")
  summary = JSON.parse(File.read(File.join(run, "summary.json")))
  assert(summary["research_dispatches"] == 1 && summary.dig("final_usage_record", "total_cost_usd") == 3, "Repeated stream events double-counted")

  FileUtils.cp(File.join(packages.first, "manifest.json"), File.join(run, "manifest.json"))
  File.write(File.join(run, "request.json"), JSON.generate("request" => {"gem" => "activesupport", "currentVersion" => "8.0.5", "requestedVersion" => "8.1.4"}))
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
  copied_eval = File.join(dir, "eval")
  FileUtils.cp_r(File.join(root, "eval"), copied_eval)
  FileUtils.cp_r(File.join(root, "fixture"), dir)
  FileUtils.cp_r(File.join(root, "plugins"), dir)
  File.open(File.join(copied_eval, "answer_key.rb"), "a") { |file| file.puts("# changed after trial") }
  review["findings"].first.merge!("status" => "found", "quote" => "Source-linked report")
  File.write(review_path, JSON.generate(review))
  _out, errors, status = Open3.capture3("ruby", File.join(copied_eval, "grade.rb"), run, review_path)
  assert(!status.success? && errors.include?("Freeze changed:"), "Grading accepted modified rubric with unchanged freeze")
end
puts "PASS: deterministic answer-free snapshot, overwrite rejection, real namespace containment, isolated CLI, streaming handoff, trace deduplication, final usage record and review validation. No paid sessions."
