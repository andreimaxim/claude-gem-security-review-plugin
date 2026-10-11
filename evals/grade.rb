#!/usr/bin/env ruby
# Validate an evidence-bearing human/blind review, not keyword-match correctness.
require "json"
require "digest"
require_relative "answer_key"
directory, review_path = ARGV
abort "Usage: ruby evals/grade.rb RUN_DIRECTORY REVIEW_JSON" unless ARGV.length == 2
abort "Freeze verification failed" unless system("ruby", File.join(__dir__, "verify.rb"), out: File::NULL)
summary = JSON.parse(File.read(File.join(directory, "summary.json")))
abort "Execution failure is not a quality score" unless summary.dig("execution", "status") == "completed" && summary["research_dispatches"] == 1 && summary["request_matches"] && summary["main_handoff"]
abort "Request changed since capture" unless summary.fetch("request_sha256") == Digest::SHA256.file(File.join(directory, "request.json")).hexdigest
abort "Manifest changed since capture" unless summary.fetch("manifest_sha256") == Digest::SHA256.file(File.join(directory, "manifest.json")).hexdigest
manifest = JSON.parse(File.read(File.join(directory, "manifest.json")))
abort "Checkout does not match trial rubric; use the original frozen revision" unless manifest.fetch("freeze_sha256") == Digest::SHA256.file(File.join(__dir__, "freeze.json")).hexdigest
source = JSON.parse(File.read(File.join(__dir__, "fixture_source.json")))
abort "Application pin differs from trial" unless manifest.fetch("application_source") == source
report = File.read(File.join(directory, "report.txt"))
review = JSON.parse(File.read(review_path))
report_hash = Digest::SHA256.hexdigest(report)
abort "Report changed since capture or review" unless summary.fetch("report_sha256") == report_hash && review.fetch("report_sha256") == report_hash
item = JSON.parse(File.read(File.join(directory, "request.json")))
abort "Request differs from manifest case" unless manifest.fetch("cases").include?(item)
abort "This case has no frozen quality rubric; review it as an exploratory run" unless item["rubric_version"] == ANSWER_KEY["version"]
request = item.fetch("request")
expected = ANSWER_KEY["issues"].select { |item| request["gem"] == "rails" || item["gem"] == request["gem"] }
expected = [] if request["currentVersion"] == request["requestedVersion"]
findings = review.fetch("findings")
abort "Wrong or duplicate reviewed IDs" unless findings.map { |item| item.fetch("id") }.sort == expected.map { |item| item.fetch("id") }.sort
sources = JSON.parse(File.read(File.join(__dir__, "sources.json"))).map { |source| source.fetch("url") }
sources += manifest.fetch("application_files").map { |path| "#{source.fetch('repository')}/blob/#{source.fetch('revision')}/#{path}" }
findings.each do |finding|
  abort "Invalid assessment" unless %w[found omitted uncertain].include?(finding.fetch("status"))
  quote = finding.fetch("quote")
  abort "Nonliteral finding quote" unless quote.empty? || report.include?(quote)
  abort "Found assessment requires a quote" if finding["status"] == "found" && quote.empty?
  abort "Omission cannot have a report quote" if finding["status"] == "omitted" && !quote.empty?
  abort "Missing reviewer rationale" if finding.fetch("reason").strip.empty?
  abort "Reference is not frozen source" unless finding.fetch("sources").any? && (finding["sources"] - sources).empty?
end
review.fetch("false_claims").each do |claim|
  abort "Nonliteral false-claim quote" if claim.fetch("quote").empty? || !report.include?(claim["quote"])
  abort "Missing false-claim rationale" if claim.fetch("reason").strip.empty?
  abort "Unknown source reference" unless claim.fetch("sources").any? && (claim["sources"] - sources).empty?
end
result = { "rubric_version" => ANSWER_KEY["version"], "review_sha256" => Digest::SHA256.file(review_path).hexdigest,
           "assessments" => findings.group_by { |item| item["status"] }.transform_values(&:length),
           "false_claims" => review["false_claims"].size,
           "limit" => "Validates review completeness, quotes and sources; reviewer owns semantic correctness. Preserve revisions as new files." }
File.write(File.join(directory, "grade-#{result['review_sha256'][0, 12]}.json"), JSON.pretty_generate(result) + "\n", mode: "wx")
puts JSON.pretty_generate(result)
