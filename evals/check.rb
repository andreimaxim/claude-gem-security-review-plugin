#!/usr/bin/env ruby
# Reproduce the upgrade in the existing app, then reverse only our own patches.
require "json"
require "open3"
require "securerandom"
require_relative "answer_key"
require_relative "application"

abort "Usage: ruby evals/check.rb APP_DIRECTORY [NEW_RESULTS_JSON]" unless (1..2).cover?(ARGV.size)
app = EvaluationApplication.validate(ARGV.first)
observations = { "baseline" => {}, "target" => {} }
applied = []
(ANSWER_KEY["issues"] + ANSWER_KEY["controls"]).each do |item|
  abort "Missing app surface: #{item['id']}" unless File.file?(File.join(app, item.fetch("location")))
end

def patch(app, path, reverse: false)
  command = ["git", "-C", app, "apply"]
  command << "--reverse" if reverse
  out, errors, status = Open3.capture3(*command, path)
  raise "Patch failed: #{path}\n#{out}\n#{errors}" unless status.success?
end

def unwind(app, applied)
  until applied.empty?
    patch(app, applied.last, reverse: true)
    applied.pop
  end
end

def boot(app)
  out, errors, status = Open3.capture3({ "APP_ROOT" => app, "RAILS_ENV" => "test",
    "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true" },
    "bundle", "exec", "ruby", File.join(__dir__, "boot_probe.rb"), chdir: app)
  raise "Boot probe did not return an observation:\n#{errors}\n#{out}" unless status.success?
  JSON.parse(out.lines.last)
end

def probe(app)
  database = "margin_notes_probe_#{SecureRandom.hex(6)}"
  _out, errors, status = Open3.capture3("createdb", database)
  raise "Cannot create disposable PostgreSQL database: #{errors}" unless status.success?
  begin
    out, errors, status = Open3.capture3({ "APP_ROOT" => app, "NOTEBOOK_DB" => database, "RAILS_ENV" => "test",
      "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true" },
      "bundle", "exec", "ruby", File.join(__dir__, "probe.rb"), chdir: app)
    raise "Application probe crashed:\n#{errors}\n#{out}" unless status.success?
    JSON.parse(out.lines.last)
  ensure
    _out, errors, status = Open3.capture3("dropdb", database)
    raise "Could not remove disposable database #{database}: #{errors}" unless status.success?
  end
end

begin
  baseline_boot = boot(app)
  raise "Baseline does not instantiate notes: #{baseline_boot.inspect}" unless baseline_boot["boot"] == "ready"
  observations["baseline"] = probe(app)
  BOOT_ROWS.each { |row| observations["baseline"][row.first] = "ready" }

  rails_patch = File.join(__dir__, "patches/stages/01-rails.patch")
  patch(app, rails_patch)
  applied << rails_patch
  ANSWER_KEY["issues"].select { |item| item["repair_patch"] }.each do |item|
    result = boot(app)
    raise "Wrong boot failure for #{item['id']}: #{result.inspect}" unless result["boot"] == item["target"] && result.fetch("message", "").include?(item["target_message"])
    observations["target"][item["probe"]] = result["boot"]
    repair = File.join(__dir__, item["repair_patch"])
    patch(app, repair)
    applied << repair
  end
  raise "Boot repairs did not restore note initialization" unless boot(app)["boot"] == "ready"
  observations["target"].merge!(probe(app))

  failures = []
  (ANSWER_KEY["issues"] + ANSWER_KEY["controls"]).each do |item|
    %w[baseline target].each do |stack|
      actual = observations.fetch(stack).fetch(item.fetch("probe"))
      failures << "#{item['id']} #{stack}: expected #{item[stack].inspect}, got #{actual.inspect}" unless actual == item[stack]
    end
  end
  raise failures.join("\n") unless failures.empty?

  unwind(app, applied)
  %w[rails-8.1-fixes.patch regression-tests.patch].each do |name|
    path = File.join(__dir__, "patches", name)
    patch(app, path)
    applied << path
  end
  %w[12345 67890].each do |seed|
    out, errors, status = Open3.capture3({ "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true" },
      "bundle", "exec", "ruby", "bin/rails", "test", "--seed", seed, chdir: app)
    raise "Repaired application tests failed:\n#{out}\n#{errors}" unless status.success?
    puts out.lines.grep(/\d+ runs, \d+ assertions/)
  end
ensure
  unwind(app, applied)
end

EvaluationApplication.validate(app)
if ARGV[1]
  File.write(ARGV[1], JSON.pretty_generate({ "application" => JSON.parse(File.read(File.join(__dir__, "fixture_source.json"))),
    "observations" => observations, "repaired_tests" => "passed seeds 12345 and 67890" }) + "\n", mode: "wx")
end
puts "PASS: #{ANSWER_KEY['issues'].size} distinct upgrade impacts and #{ANSWER_KEY['controls'].size} controls reproduced."
puts "Target observations follow six separately reproduced prerequisite failures; reference repair tests pass."
puts "App restored to its frozen Rails 7 revision. No model research trials executed."
