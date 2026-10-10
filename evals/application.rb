#!/usr/bin/env ruby
# Check the existing application in the Orb; never clone or change its revision.
require "json"
require "open3"

module EvaluationApplication
  def self.validate(path)
    app = File.realpath(path)
    source = JSON.parse(File.read(File.join(__dir__, "fixture_source.json")))
    { "--show-toplevel" => app, "HEAD" => source.fetch("revision"), "HEAD^{tree}" => source.fetch("tree") }.each do |argument, expected|
      value, errors, status = Open3.capture3("git", "-C", app, "rev-parse", argument)
      abort "Application does not match its frozen revision: #{errors}" unless status.success? && value.strip == expected
    end
    _out, errors, status = Open3.capture3("git", "-C", app, "diff", "--quiet", "HEAD", "--")
    abort "Application has tracked changes: #{errors}" unless status.success?
    files, errors, status = Open3.capture3("git", "-C", app, "ls-files", "--others", "--exclude-standard", "-z")
    abort "Application has untracked files: #{errors}" unless status.success? && files.empty?
    app
  end
end
