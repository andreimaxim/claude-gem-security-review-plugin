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
  suffix = "#{source.fetch('repository')}/#{source.fetch('tag')}/#{source.fetch('file')}"
  abort "Source URL/path mismatch" unless source["url"] == "https://raw.githubusercontent.com/#{suffix}" && source["path"] == "evidence/#{suffix}"
end
items.each do |item|
  required = if item["source"]
    [ANSWER_KEY.fetch("baseline_rails"), ANSWER_KEY.fetch("target_rails")].map do |version|
      { "repository" => "rails/rails", "tag" => "v#{version}", "file" => item.fetch("source") }
    end
  else
    []
  end
  required += item.fetch("external_evidence", [])
  abort "No source evidence: #{item['id']}" if required.empty?
  files = required.map do |ref|
    source = sources.find { |entry| ref.all? { |field, value| entry[field] == value } }
    abort "Missing tagged source: #{item['id']} #{ref.inspect}" unless source
    File.join(__dir__, source.fetch("path"))
  end
  # Removed APIs need not leave an anchor in the new tag. Runtime reproduction
  # and semantic review, not this existence check, establish the change.
  abort "Source anchor missing: #{item['id']}" if item["anchor"] && !files.any? { |path| File.read(path).include?(item.fetch("anchor")) }
end

JSON.parse(File.read(File.join(__dir__, "freeze.json"))).each do |path, hash|
  abort "Freeze changed: #{path}" unless Digest::SHA256.file(File.join(root, path)).hexdigest == hash
end
puts "PASS: frozen application pin, plugin, rubric and #{sources.length} tagged source files; #{ANSWER_KEY['issues'].length} positives + #{ANSWER_KEY['controls'].length} controls."
abort "INCOMPLETE: requested issue count has not been achieved." unless ANSWER_KEY["issues"].length == ANSWER_KEY.fetch("requested_positive_count")
