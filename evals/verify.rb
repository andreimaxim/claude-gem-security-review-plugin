#!/usr/bin/env ruby
require "json"
require "digest"
require_relative "answer_key"

root = File.expand_path("..", __dir__)
items = ANSWER_KEY.fetch("issues") + ANSWER_KEY.fetch("controls")
abort "Duplicate issue/control IDs or probes" unless %w[id probe].all? { |field| items.map { |item| item.fetch(field) }.uniq.size == items.size }
abort "A positive finding has no before/after distinction" unless ANSWER_KEY["issues"].all? { |item| item["baseline"] != item["target"] }
abort "A control has changed" unless ANSWER_KEY["controls"].all? { |item| item["baseline"] == item["target"] }

sources = JSON.parse(File.read(File.join(__dir__, "sources.json")))
sources.each do |source|
  path = File.join(__dir__, source.fetch("path"))
  abort "Changed source: #{path}" unless Digest::SHA256.file(path).hexdigest == source.fetch("sha256")
  expected_url = "https://raw.githubusercontent.com/rails/rails/" + source["path"].delete_prefix("evidence/")
  abort "Source URL/path mismatch" unless source["url"] == expected_url
end
items.each do |item|
  files = [ANSWER_KEY.fetch("baseline_rails"), ANSWER_KEY.fetch("target_rails")].map { |version| "evidence/v#{version}/#{item.fetch('source')}" }
  abort "Missing tagged source pair: #{item['id']}" unless files.all? { |path| sources.any? { |source| source["path"] == path } }
  abort "Source anchor missing: #{item['id']}" unless files.any? { |path| File.read(File.join(__dir__, path)).include?(item.fetch("anchor")) }
end

JSON.parse(File.read(File.join(__dir__, "freeze.json"))).each do |path, hash|
  abort "Freeze changed: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == hash
end
puts "PASS: frozen application pin, plugin, rubric and #{sources.length} tagged source files; #{ANSWER_KEY['issues'].length} positives + #{ANSWER_KEY['controls'].length} controls."
abort "INCOMPLETE: requested issue count has not been achieved." unless ANSWER_KEY["issues"].length == ANSWER_KEY.fetch("requested_positive_count")
