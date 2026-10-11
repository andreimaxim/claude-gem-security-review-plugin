#!/usr/bin/env ruby
require "json"
require "digest"
require "fileutils"
require "open3"
require_relative "answer_key"
require_relative "application"

application, destination = ARGV
abort "Usage: ruby evals/prepare.rb APP_DIRECTORY NEW_DIRECTORY" unless ARGV.length == 2
root = File.expand_path("..", __dir__)
destination = File.expand_path(destination)
abort "Choose a directory outside this repository" if destination == root || destination.start_with?(root + "/")
abort "Refusing to overwrite #{destination}" if File.exist?(destination)
abort "Benchmark incomplete" unless ANSWER_KEY["issues"].length == ANSWER_KEY.fetch("requested_positive_count")
abort "Freeze verification failed" unless system("ruby", File.join(__dir__, "verify.rb"))
app = EvaluationApplication.validate(application)

FileUtils.mkdir_p(destination)
snapshot = File.join(destination, "application.tar")
frozen_files = JSON.parse(File.read(File.join(__dir__, "freeze.json"))).keys
files, errors, status = Open3.capture3("git", "-C", app, "ls-files", "-z")
abort errors unless status.success?
abort "Unexpected snapshot path" unless files.split("\0").all? { |path| !path.start_with?("/") && !path.split("/").include?("..") }
_out, errors, status = Open3.capture3("tar", "--sort=name", "--mtime=@0", "--owner=0", "--group=0", "--numeric-owner", "-cf", snapshot, "--null", "-T", "-", stdin_data: files, chdir: app)
abort errors unless status.success?

plugin = File.join(destination, "plugin")
frozen_files.reject { |path| path.start_with?("evals/") }.each do |path|
  target = File.join(plugin, path)
  FileUtils.mkdir_p(File.dirname(target))
  FileUtils.cp(File.join(root, path), target)
end
observer = File.read(File.join(__dir__, "observe.ts")).split("export const register: Register = (on) => {", 2).fetch(1).delete_suffix("}\n")
registration = File.join(plugin, "hooks/register.ts")
File.write(registration, File.read(registration).sub(/\n}\s*\z/, "\n#{observer}\n}\n"))

cases = (["rails"] + ANSWER_KEY["issues"].map { |item| item["gem"] }.uniq.sort).uniq.map do |gem|
  { "id" => gem, "request" => { "gem" => gem, "currentVersion" => ANSWER_KEY.fetch("baseline_rails"), "requestedVersion" => ANSWER_KEY.fetch("target_rails") }, "control" => false, "rubric_version" => ANSWER_KEY["version"] }
end
cases << { "id" => "jbuilder-same-version", "request" => { "gem" => "jbuilder", "currentVersion" => "2.13.0", "requestedVersion" => "2.13.0" }, "control" => true, "rubric_version" => ANSWER_KEY["version"] }
cases << { "id" => "redis", "request" => { "gem" => "redis", "currentVersion" => "4.8.1", "requestedVersion" => "5.4.1" }, "control" => false, "rubric_version" => nil }
manifest = {
  "schema_version" => 2, "status" => ANSWER_KEY["status"], "positive_issues" => ANSWER_KEY["issues"].size,
  "requested_positive_issues" => ANSWER_KEY.fetch("requested_positive_count"), "nonissue_controls" => ANSWER_KEY["controls"].size,
  "application_source" => JSON.parse(File.read(File.join(__dir__, "fixture_source.json"))),
  "application_files" => files.split("\0"),
  "application_sha256" => Digest::SHA256.file(snapshot).hexdigest,
  "freeze_sha256" => Digest::SHA256.file(File.join(__dir__, "freeze.json")).hexdigest,
  "plugin_files" => Dir.glob("#{plugin}/**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) }.sort.to_h { |path| [path.delete_prefix(plugin + "/"), Digest::SHA256.file(path).hexdigest] },
  "cases" => cases
}
File.write(File.join(destination, "manifest.json"), JSON.pretty_generate(manifest) + "\n")
puts "Prepared #{cases.size} requests (not #{cases.size} distinct issues) in #{destination}; #{manifest['positive_issues']}/#{manifest['requested_positive_issues']} positive issues."
