#!/usr/bin/env ruby
# Render a recorded individual report in the comparison template's detail style.
require "json"
require "digest"

abort "Usage: ruby evals/render_report.rb RUN_DIRECTORY" unless ARGV.size == 1
directory = File.realpath(ARGV.first)
review = JSON.parse(File.read(File.join(directory, "review.json")))
request = JSON.parse(File.read(File.join(directory, "request.json"))).fetch("request")
report = File.read(File.join(directory, "report.txt"))
abort "Report differs from review" unless Digest::SHA256.hexdigest(report) == review.fetch("report_sha256")
review.fetch("findings").each do |finding|
  abort "Nonliteral finding quotation" unless report.include?(finding.fetch("quote"))
end
model_label = review.fetch("metrics").fetch("model").sub(/\Aclaude-(opus|sonnet|haiku)-(\d+)-(\d+)\z/) do
  "#{$1.capitalize} #{$2}.#{$3}"
end
data = review.merge("request" => request, "report" => report,
  "run_id" => File.basename(directory).split("-").last(2).join("-"),
  "model_label" => model_label, "metrics_csv" => File.read(File.join(directory, "metrics.csv")))
template = File.read(File.join(__dir__, "report-template.html"))
html = template.sub("__REPORT_DATA__") { JSON.generate(data).gsub("<", "\\u003c") }
File.write(File.join(directory, "redis-smoke.html"), html)
puts "Rendered individual report with verified original text and literal findings; no model session."
