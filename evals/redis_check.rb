#!/usr/bin/env ruby
# Ground truth for an exploratory Redis smoke run, not a scored holdout.
require "json"
require "open3"
require "securerandom"
require_relative "application"
require_relative "answer_key"

abort "Usage: ruby evals/redis_check.rb APP_DIRECTORY NEW_RESULTS_JSON" unless ARGV.size == 2
app = EvaluationApplication.validate(ARGV.first)
abort "Refusing to overwrite results" if File.exist?(ARGV.last)
result = { "application" => JSON.parse(File.read(File.join(__dir__, "fixture_source.json"))), "stacks" => {} }
{ "baseline" => File.join(app, "Gemfile"), "target" => File.join(__dir__, "redis.Gemfile") }.each do |stack, gemfile|
  database = "margin_notes_redis_#{SecureRandom.hex(6)}"
  raise "Cannot create observation database" unless system("createdb", database)
  begin
    env = { "BUNDLE_GEMFILE" => gemfile, "BUNDLE_FROZEN" => "true", "APP_ROOT" => app, "NOTEBOOK_DB" => database, "RAILS_ENV" => "test" }
    out, errors, status = Open3.capture3(env, "bundle", "exec", "ruby", File.join(__dir__, "probe.rb"), chdir: app)
    raise "Redis #{stack} probe failed:\n#{errors}\n#{out}" unless status.success?
    observations = JSON.parse(out.lines.last)
    rows = ANSWER_KEY["issues"].reject { |item| item["repair_patch"] } + ANSWER_KEY["controls"] + ANSWER_KEY["diagnostics"]
    rows.each do |item|
      raise "Unexpected #{stack} change: #{item['probe']}" unless observations.fetch(item["probe"]) == item["baseline"]
    end
    out, errors, status = Open3.capture3(env, "bundle", "exec", "ruby", "bin/rails", "test", "--seed", "12345", chdir: app)
    raise "Redis #{stack} smoke tests failed:\n#{errors}\n#{out}" unless status.success?
    counts = out.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/)
    raise "Missing Minitest result" unless counts
    result["stacks"][stack] = { "observations" => observations,
      "tests" => %w[runs assertions failures errors skips].zip(counts.captures.map(&:to_i)).to_h }
    puts "#{stack}: #{counts[0]}"
  ensure
    raise "Cannot remove observation database" unless system("dropdb", database)
  end
end
raise "Wrong Redis stacks" unless result.dig("stacks", "baseline", "observations", "runtime", "gems", "redis") == "4.8.1" && result.dig("stacks", "target", "observations", "runtime", "gems", "redis") == "5.4.1"
EvaluationApplication.validate(app)
File.write(ARGV.last, JSON.pretty_generate(result) + "\n", mode: "wx")
puts "PASS: current app observations and smoke suite agree under both Redis clients. No app edits or model sessions."
