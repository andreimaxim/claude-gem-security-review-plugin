#!/usr/bin/env ruby
# Run both locked stacks on disposable, file-backed SQLite databases.
require "json"
require "tmpdir"
require "fileutils"
require "open3"
require "digest"
require_relative "answer_key"
require_relative "application"

key = ANSWER_KEY
observations = {}
abort "Usage: ruby evals/check.rb APP_DIRECTORY" unless ARGV.length == 1
app = EvaluationApplication.validate(ARGV.first)
(key.fetch("issues") + key.fetch("controls")).each do |item|
  abort "Missing app surface: #{item['id']}" if item["location"] && !File.file?(File.join(app, item["location"]))
end
Dir.mktmpdir("notebook-eval-") do |dir|
  %w[baseline target].each do |stack|
    gemfile = stack == "baseline" ? File.join(app, "Gemfile") : File.join(__dir__, "target.Gemfile")
    env = { "BUNDLE_GEMFILE" => gemfile, "APP_ROOT" => app,
            "NOTEBOOK_DB" => File.join(dir, "#{stack}.sqlite3"), "RAILS_ENV" => "test" }
    out, errors, status = Open3.capture3(env, "bundle", "exec", "ruby", File.join(__dir__, "probe.rb"))
    abort "#{stack} probe crashed:\n#{errors}\n#{out}" unless status.success?
    observations[stack] = JSON.parse(out.lines.last)
  end
end

failed = []
(key.fetch("issues") + key.fetch("controls")).each do |item|
  %w[baseline target].each do |stack|
    expected = item.fetch(stack)
    actual = observations.fetch(stack).fetch(item.fetch("probe"))
    failed << "#{item['id']} #{stack}: expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
  end
end
abort failed.join("\n") unless failed.empty?
puts "PASS: #{key['issues'].length} distinct impacts and #{key['controls'].length} nonissue controls on both locked stacks."
puts "Same unmodified Rails 8 application on both stacks; no prerequisite repairs."
puts "Coverage: #{key['issues'].length}/#{key.fetch('requested_positive_count')} requested positive issues; no model research trials executed."
abort "INCOMPLETE: requested issue count has not been achieved." unless key["issues"].length == key.fetch("requested_positive_count")
