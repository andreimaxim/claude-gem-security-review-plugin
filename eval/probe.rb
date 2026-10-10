# Evaluator only: never shipped to the testing agent.
require "json"
require "stringio"
require "bigdecimal"
require File.join(ENV.fetch("APP_ROOT"), "config/environment")
require "action_dispatch/testing/integration"
load File.join(Rails.root, "db/migrate/20200101000000_create_notes.rb")
CreateNotes.new.migrate(:up)
%w[a b ccccc].each { |title| Note.create!(title: title) }
connection = ActiveRecord::Base.connection
results = {}
def observe(results, id)
  results[id] = yield
rescue StandardError => error
  warn "#{id}: #{error.full_message}" if ENV["PROBE_DEBUG"]
  results[id] = { "error" => error.class.name }
end

observe(results, "sqlite_cast") { NotebookWorkflows.export_timestamps.first.class.name }
session = ActionDispatch::Integration::Session.new(Rails.application)
observe(results, "local_cache") do
  Rails.cache.write("live-status", "old")
  session.get("/cache-status")
  JSON.parse(session.response.body)
end
observe(results, "long_key") do
  key = "x" * 300 + "/notes/123"
  NotebookWorkflows.cache_export(key, "export")
  NotebookWorkflows.expire_note_exports
  Rails.cache.read(key)
end
observe(results, "sse_batch") do
  stream = Object.new
  writes = []
  stream.define_singleton_method(:write) { |text| writes << text }
  sse = ActionController::Live::SSE.new(stream)
  NotebookWorkflows.write_event(sse)
  writes.length
end
observe(results, "stream_buffer") do
  response = ActionDispatch::Response.new
  buffer = +"é"
  value = NotebookWorkflows.write_chunk(response.stream, buffer)
  buffer.replace("changed")
  result = { "return" => value.class.name, "body" => response.body }
  result["bytes"] = value if value.is_a?(Integer)
  result
end
observe(results, "parameter_encoding") do
  session.get("/notes?%FF=value", headers: { "Accept" => "application/json" })
  # Force parsing through the request interface, even though the index action
  # itself does not need params. Baseline accepts invalid bytes in the key.
  session.request.query_parameters.keys.first.valid_encoding?
end
observe(results, "limit") { Note.exportable("invalid").class.name }
observe(results, "distinct_average") { Note.average_title_length.to_f }
observe(results, "grouped_update") do
  Note.archive_group(Note.order(:id).first.id)
  Note.where(archived: true).count
end
observe(results, "bulk_deprecation") do
  warnings = []
  old = ActiveRecord.deprecator.behavior
  begin
    ActiveRecord.deprecator.behavior = ->(message, *) { warnings << message }
    Note.publish_unique
  ensure
    ActiveRecord.deprecator.behavior = old
  end
  warnings.any? { |message| message.include?("distinct") && message.include?("8.2") }
end
observe(results, "delete_multi") do
  Rails.cache.write("expired", 1)
  NotebookWorkflows.expire_exports(["expired"].freeze)
end
observe(results, "head_after_render") do
  session.get("/preview.json")
  session.response.status
end

observe(results, "sql_boolean") { [true, false].map { |value| NotebookWorkflows.sql_boolean(value) } }
observe(results, "nested_isolation") { NotebookWorkflows.isolated_export(connection) }
observe(results, "serializer_precedence") do
  ActiveJob::Arguments.serialize([ExportDestination.new("archive")]).first.fetch("format")
end
observe(results, "duration_precision") { NotebookWorkflows.elapsed_minutes(90.5) }
observe(results, "frozen_advance") { NotebookWorkflows.advance_deadline(Time.utc(2020, 1, 1), {days: 1.5}.freeze).iso8601 }
observe(results, "indifferent_filter") { NotebookWorkflows.author_name({"name" => "Ada", "role" => "editor"}) }
observe(results, "blank_locale") { Rails.application.routes.url_helpers.catalog_path(locale: "", id: 123) }
observe(results, "http_date") do
  session.get("/freshness", headers: {"If-Modified-Since" => "Sunday, 06-Nov-94 08:49:37 GMT"})
  session.response.status
end
observe(results, "nil_separator") { NotebookWorkflows.export_slug("Donald E. Knuth") }

observe(results, "cache_format_control") { ActiveSupport::Cache.format_version }
observe(results, "strict_sqlite_control") { connection.select_value('SELECT "literal"') }
observe(results, "strong_params_control") do
  ActionController::Parameters.new(note: { title: "a", extra: "b" }).require(:note).permit(:title).to_h
end
observe(results, "sse_control") do
  Note.delete_all
  Note.create!(title: "stream")
  session.get("/stream")
  session.response.body
end
observe(results, "job_zone_control") do
  deadline = Time.find_zone!("Asia/Tokyo").local(2020, 1, 1)
  job = NotebookWorkflows.build_export("zone", amount: BigDecimal("1.25"), deadline: deadline)
  # Observe the actual inline adapter's deserialize-and-execute path.
  captured = nil
  ExportJob.around_perform do |instance, block|
    captured = instance.arguments[2].time_zone.name
    block.call
  end
  job.enqueue
  captured
end
observe(results, "json_escape_control") do
  ActiveSupport::JSON.encode({ "text" => "line\u2028break" }).include?("\\u2028")
end

# Boot/CRUD checks are prerequisites, not extra counted upgrade issues.
session.get("/health")
raise "Health endpoint failed" unless session.response.status == 200 && JSON.parse(session.response.body) == { "status" => "ok" }
session.post("/notes", params: { note: { title: "boot" } })
raise "Note creation failed" unless session.response.status == 302 && Note.where(title: "boot").count == 1
session.get("/notes.json")
body = JSON.parse(session.response.body)
raise "Jbuilder listing failed" unless session.response.status == 200 && body.fetch("notes").map { |note| note.fetch("caption") } == %w[stream zone boot]
puts JSON.generate(results)
