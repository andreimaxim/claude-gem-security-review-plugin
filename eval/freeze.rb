#!/usr/bin/env ruby
# Maintainer action after source review and passing runtime checks, before trials.
require "json"
require "digest"
root = File.expand_path("..", __dir__)
path = File.join(__dir__, "freeze.json")
abort "Already frozen. Revise in a reviewed commit; do not rewrite during trials." if File.exist?(path)
files = Dir.glob("#{root}/fixture/**/*", File::FNM_DOTMATCH).select { |file| File.file?(file) && !file.match?(%r{/(log|tmp)/|\.sqlite3}) }
files += Dir.glob("#{root}/plugins/gem-upgrade/**/*", File::FNM_DOTMATCH).select { |file| File.file?(file) && !file.include?("/.claude-plugin/types/") }
files += Dir.glob("#{__dir__}/*").select { |file| File.file?(file) && file != path }
manifest = files.sort.to_h { |file| [file.delete_prefix(root + "/"), Digest::SHA256.file(file).hexdigest] }
File.write(path, JSON.pretty_generate(manifest) + "\n")
puts "Frozen #{manifest.size} evaluator/application/plugin files. Tagged evidence is independently hashed in sources.json."
