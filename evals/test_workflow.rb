#!/usr/bin/env ruby
# Public workflow invariants; no paid sessions or model correctness assertions.
require "json"
require "digest"
require "tmpdir"
require "fileutils"
require "open3"
root = File.expand_path("..", __dir__)
abort "Usage: ruby evals/test_workflow.rb APP_DIRECTORY" unless ARGV.length == 1
application = File.expand_path(ARGV.first)
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
  names.each do |path|
    bytes, errors, status = Open3.capture3("tar", "-xOf", File.join(packages.first, "application.tar"), path)
    assert(status.success? && bytes.b == File.binread(File.join(application, path)), "Snapshot differs from live application: #{path} #{errors}")
  end

  run = File.join(dir, "trace-test")
  FileUtils.mkdir_p(run)
  manifest = JSON.parse(File.read(File.join(packages.first, "manifest.json")))
  item = manifest.fetch("cases").find { |entry| entry["id"] == "activesupport" }
  FileUtils.cp(File.join(packages.first, "manifest.json"), File.join(run, "manifest.json"))
  File.write(File.join(run, "request.json"), JSON.generate(item))
  tool = { "type" => "assistant", "message" => { "content" => [{ "type" => "tool_use", "id" => "call-1", "name" => "mcp__gem-upgrade__research", "input" => item.fetch("request") }] } }
  acknowledgement = {"type" => "user", "message" => {"content" => [{"type" => "tool_result", "tool_use_id" => "call-1", "content" => "Research started for activesupport 7.0.8.7 → 8.1.4 (agent worker-1)."}]}}
  events = [tool, tool, {"type" => "result", "result_index" => 1, "total_cost_usd" => 1},
            acknowledgement,
            {"type" => "system", "subtype" => "task_notification", "task_id" => "worker-1", "run_id" => "run-1", "status" => "completed", "summary" => "Source-linked report"},
            {"type" => "system", "subtype" => "task_notification", "task_id" => "unrelated-worker", "status" => "completed", "summary" => "Unrelated report"},
            {"type" => "result", "result_index" => 2, "total_cost_usd" => 3}]
  File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
  File.write(File.join(run, "stderr.log"), "")
  File.write(File.join(run, "execution.json"), JSON.generate("status" => "completed"))
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
  assert(!status.success?, "Uncorrelated or earlier result accepted as handoff")
  events.last["origin"] = { "kind" => "task-notification", "runId" => "unrelated-run" }
  File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
  _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
  assert(!status.success?, "Another worker's handoff accepted")
  payload = "Research activesupport 7.0.8.7 → 8.1.4 (agent worker-1) completed.\n\nSource-linked report"
  events.last.merge!("subtype" => "success", "is_error" => false, "result" => payload)
  events.last["origin"]["runId"] = "run-1"
  valid_result = Marshal.load(Marshal.dump(events.last))
  [
    valid_result.merge("result" => "Still waiting"),
    valid_result.merge("result" => payload.sub("worker-1", "other-worker")),
    valid_result.merge("result" => payload.sub("8.1.4", "8.1.3")),
    valid_result.merge("result" => "Example:\n#{payload}"),
    valid_result.merge("result" => payload.delete_suffix("report")),
    valid_result.merge("origin" => nil),
    valid_result.merge("origin" => {"kind" => "human"}),
    valid_result.merge("origin" => {"kind" => "task-notification", "runId" => nil}),
    valid_result.merge("origin" => {"kind" => "task-notification", "runId" => "other-run"}),
    valid_result.merge("is_error" => true),
    valid_result.merge("subtype" => "error_during_execution")
  ].each do |invalid|
    events[-1] = invalid
    File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
    _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
    assert(!status.success?, "Malformed or unrelated handoff accepted: #{invalid.inspect}")
  end
  [true, false].each do |with_run_id|
    events[-1] = valid_result.merge("origin" => with_run_id ? valid_result["origin"] : {"kind" => "task-notification"})
    [events, events.values_at(0, 1, 2, 3, 6, 5, 4)].each do |ordered|
      File.write(File.join(run, "trace.jsonl"), ordered.map { |event| JSON.generate(event) }.join("\n") + "\n")
      _out, _errors, status = Open3.capture3("ruby", File.join(__dir__, "summarize.rb"), run)
      assert(status.success?, "Exact report handoff rejected because of event order or absent optional run ID")
    end
  end
  File.write(File.join(run, "trace.jsonl"), events.map { |event| JSON.generate(event) }.join("\n") + "\n")
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
  original_request = File.read(File.join(run, "request.json"))
  File.write(File.join(run, "request.json"), JSON.generate(manifest.fetch("cases").find { |entry| entry["id"] == "jbuilder-same-version" }))
  File.write(review_path, JSON.generate(review.merge("findings" => [])))
  _out, errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(!status.success? && errors.include?("Request changed since capture"), "Same-version request substitution accepted")
  File.write(File.join(run, "request.json"), original_request)
  File.write(review_path, JSON.generate(review))
  original_manifest = File.read(File.join(run, "manifest.json"))
  File.write(File.join(run, "manifest.json"), JSON.generate(manifest.merge("application_files" => ["invented.rb"])))
  _out, errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(!status.success? && errors.include?("Manifest changed since capture"), "Manifest substitution accepted")
  File.write(File.join(run, "manifest.json"), original_manifest)
  source = manifest.fetch("application_source")
  review["false_claims"] = [{ "quote" => "Source-linked report", "reason" => "Protocol fixture, not a semantic correctness assertion",
    "sources" => ["#{source.fetch('repository')}/blob/#{source.fetch('revision')}/app/models/note.rb",
      "https://raw.githubusercontent.com/rails/jbuilder/v2.13.0/lib/jbuilder.rb"] }]
  File.write(review_path, JSON.generate(review))
  _out, errors, status = Open3.capture3("ruby", File.join(__dir__, "grade.rb"), run, review_path)
  assert(status.success?, "Frozen application or same-version gem reference rejected: #{errors}")
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
puts "PASS: deterministic answer-free snapshot, overwrite rejection, correlated handoff, trace deduplication, request/manifest/report identity and evidence-bearing review validation. No isolation checks or paid sessions."
