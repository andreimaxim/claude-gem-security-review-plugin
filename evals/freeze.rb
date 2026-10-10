#!/usr/bin/env ruby
# Maintainer action after source review and passing runtime checks, before trials.
require "json"
require "digest"
root = File.expand_path("..", __dir__)
path = File.join(__dir__, "freeze.json")
abort "Already frozen. Revise in a reviewed commit; do not rewrite during trials." if File.exist?(path)
files = %w[.claude-plugin/plugin.json README.md tsconfig.json].map { |file| File.join(root, file) }
files += Dir.glob("#{root}/{hooks,prompts}/**/*", File::FNM_DOTMATCH).select { |file| File.file?(file) }
files += Dir.glob("#{__dir__}/*", File::FNM_DOTMATCH).select { |file| File.file?(file) && file != path }
files += Dir.glob("#{__dir__}/patches/**/*").select { |file| File.file?(file) }
manifest = files.sort.to_h { |file| [file.delete_prefix(root + "/"), Digest::SHA256.file(file).hexdigest] }
File.write(path, JSON.pretty_generate(manifest) + "\n")
puts "Frozen #{manifest.size} evaluator/plugin files and application revision pin. Tagged evidence is independently hashed in sources.json."
