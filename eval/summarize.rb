#!/usr/bin/env ruby
require "json"
require "digest"
directory = ARGV.fetch(0) { abort "Usage: ruby eval/summarize.rb RUN_DIRECTORY" }
events = File.readlines(File.join(directory, "trace.jsonl")).map { |line| JSON.parse(line) }
tools = {}
events.each do |event|
  Array(event.dig("message", "content")).each do |block|
    tools[block["id"]] = block if block["type"] == "tool_use"
  end
end
notifications = events.select { |event| event["subtype"] == "task_notification" && event["status"] == "completed" }
report = notifications.last&.fetch("summary", nil)
final = events.reverse.find { |event| event["type"] == "result" }
observations = (File.read(File.join(directory, "trace.jsonl")) + File.read(File.join(directory, "stderr.log")))
steps = observations.scan(/GEM_UPGRADE_EVAL_STEP (\{[^\n]*?\})/).filter_map do |(value)|
  JSON.parse(value.gsub('\\"', '"'))
rescue JSON::ParserError
  nil
end.uniq
summary = {
  "execution" => JSON.parse(File.read(File.join(directory, "execution.json"))),
  "unique_tool_calls" => tools.values.group_by { |block| block["name"] }.transform_values(&:length),
  "research_dispatches" => tools.values.count { |block| block["name"] == "mcp__gem-upgrade__research" },
  "worker_step_observations" => steps.select { |step| step["agentId"] },
  "resolved_model_effort_observed" => steps.any? { |step| step["agentId"] && step["model"] && step["effort"] },
  "final_usage_record" => final,
  "report_sha256" => report && Digest::SHA256.hexdigest(report),
  "quality" => "not graded; execution success is not research accuracy"
}
File.write(File.join(directory, "report.txt"), report) if report
File.write(File.join(directory, "summary.json"), JSON.pretty_generate(summary) + "\n")
puts JSON.pretty_generate(summary)
exit(summary["research_dispatches"] == 1 && report && !report.strip.empty? && summary["execution"]["status"] == "completed" ? 0 : 1)
