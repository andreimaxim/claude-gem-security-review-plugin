require "json"

begin
  require File.join(ENV.fetch("APP_ROOT"), "config/environment")
  Note.new(title: "Example").export_heading
  puts JSON.generate("boot" => "ready")
rescue StandardError => error
  puts JSON.generate("boot" => { "error" => error.class.name }, "message" => error.message)
end
