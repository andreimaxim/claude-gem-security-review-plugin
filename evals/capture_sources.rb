#!/usr/bin/env ruby
# Maintainer action: fetch exact tagged sources once. Refuse to rewrite a freeze.
require "json"
require "net/http"
require "digest"
require "fileutils"
require_relative "answer_key"

manifest_path = File.join(__dir__, "sources.json")
abort "Sources already frozen; review changes explicitly instead of overwriting." if File.exist?(manifest_path)
items = ANSWER_KEY["issues"] + ANSWER_KEY["controls"]
paths = items.filter_map { |row| row["source"] }.uniq.sort
paths += ["MIT-LICENSE", "rails.gemspec", "railties/lib/rails/application/bootstrap.rb", "activesupport/lib/active_support/cache/strategy/local_cache.rb", "activesupport/lib/active_support/cache/redis_cache_store.rb"]
requests = [ANSWER_KEY.fetch("baseline_rails"), ANSWER_KEY.fetch("target_rails")].flat_map do |version|
  paths.uniq.map do |path|
    { "repository" => "rails/rails", "tag" => "v#{version}", "file" => path }
  end
end
requests += items.flat_map { |row| row.fetch("external_evidence", []) }
requests += %w[v5.6.9 v6.6.1].map { |tag| { "repository" => "puma/puma", "tag" => tag, "file" => "LICENSE" } }
manifest = requests.uniq.map do |source|
  suffix = "#{source.fetch('repository')}/#{source.fetch('tag')}/#{source.fetch('file')}"
  url = "https://raw.githubusercontent.com/#{suffix}"
  response = Net::HTTP.get_response(URI(url))
  abort "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  relative = "evidence/#{suffix}"
  destination = File.join(__dir__, relative)
  FileUtils.mkdir_p(File.dirname(destination))
  File.binwrite(destination, response.body)
  puts relative
  source.merge("url" => url, "path" => relative, "sha256" => Digest::SHA256.hexdigest(response.body))
end
File.write(manifest_path, JSON.pretty_generate(manifest) + "\n")
