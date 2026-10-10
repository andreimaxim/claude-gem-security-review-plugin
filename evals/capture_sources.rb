#!/usr/bin/env ruby
# Maintainer action: fetch exact tagged sources once. Refuse to rewrite a freeze.
require "json"
require "net/http"
require "digest"
require "fileutils"
require_relative "answer_key"

manifest_path = File.join(__dir__, "sources.json")
abort "Sources already frozen; review changes explicitly instead of overwriting." if File.exist?(manifest_path)
paths = (ANSWER_KEY["issues"] + ANSWER_KEY["controls"]).map { |row| row.fetch("source") }.uniq.sort
paths += ["MIT-LICENSE", "rails.gemspec", "railties/lib/rails/application/bootstrap.rb", "activesupport/lib/active_support/cache/strategy/local_cache.rb"]
manifest = []
[ANSWER_KEY.fetch("baseline_rails"), ANSWER_KEY.fetch("target_rails")].each do |version|
  paths.each do |path|
    url = "https://raw.githubusercontent.com/rails/rails/v#{version}/#{path}"
    response = Net::HTTP.get_response(URI(url))
    abort "#{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    relative = "evidence/v#{version}/#{path}"
    destination = File.join(__dir__, relative)
    FileUtils.mkdir_p(File.dirname(destination))
    File.binwrite(destination, response.body)
    manifest << { "url" => url, "path" => relative, "sha256" => Digest::SHA256.hexdigest(response.body) }
    puts relative
  end
end
File.write(manifest_path, JSON.pretty_generate(manifest) + "\n")
