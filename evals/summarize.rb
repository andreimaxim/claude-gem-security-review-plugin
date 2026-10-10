#!/usr/bin/env ruby
require "json"
require "digest"
require_relative "research_trace"
directory = ARGV.fetch(0) { abort "Usage: ruby evals/summarize.rb RUN_DIRECTORY" }
events = File.readlines(File.join(directory, "trace.jsonl")).map { |line| JSON.parse(line) }
item = JSON.parse(File.read(File.join(directory, "request.json")))
manifest = JSON.parse(File.read(File.join(directory, "manifest.json")))
abort "Request differs from manifest case" unless manifest.fetch("cases").include?(item)
research = ResearchTrace.new(item.fetch("request"))
events.each { |event| research.observe(event) }
tools = research.tools
report = research.report
final = events.reverse.find { |event| event["type"] == "result" }
observations = (File.read(File.join(directory, "trace.jsonl")) + File.read(File.join(directory, "stderr.log")))
steps = observations.scan(/GEM_UPGRADE_EVAL_STEP (\{[^\n]*?\})/).filter_map do |(value)|
  JSON.parse(value.gsub('\\"', '"'))
rescue JSON::ParserError
  nil
end.uniq
steps.select! { |step| research.worker_id && step["agentId"] == research.worker_id }
summary = {
  "execution" => JSON.parse(File.read(File.join(directory, "execution.json"))),
  "unique_tool_calls" => tools.values.group_by { |block| block["name"] }.transform_values(&:length),
  "research_dispatches" => tools.values.count { |block| block["name"] == "mcp__gem-upgrade__research" },
  "request_matches" => research.request_matches?,
  "worker_id" => research.worker_id,
  "worker_step_observations" => steps,
  "resolved_model_effort_observed" => steps.any? { |step| step["model"] && step["effort"] },
  "final_usage_record" => final,
  "report_sha256" => report && Digest::SHA256.hexdigest(report),
  "quality" => "not graded; execution success is not research accuracy"
}
File.write(File.join(directory, "report.txt"), report) if report
File.write(File.join(directory, "summary.json"), JSON.pretty_generate(summary) + "\n")
puts JSON.pretty_generate(summary)
exit(research.request_matches? && research.handoff? && report && summary["execution"]["status"] == "completed" ? 0 : 1)
