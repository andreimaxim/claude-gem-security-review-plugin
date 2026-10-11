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

observe(results, "timestamp_cast") { NotebookWorkflows.export_timestamps.first.class.name }
session = ActionDispatch::Integration::Session.new(Rails.application)
observe(results, "local_cache") do
  Rails.cache.write("live-status", "old")
  session.get("/cache-status")
  JSON.parse(session.response.body)
end
observe(results, "long_key") do
  note = Note.order(:id).first
  namespace = "x" * 300
  session.get("/exports/#{note.id}", params: { namespace: namespace })
  raise "Export snapshot failed" unless session.response.status == 200
  session.post("/exports/expire")
  raise "Export expiry failed" unless session.response.status == 204
  !Rails.cache.read("#{namespace}/notes/#{note.id}").nil?
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
observe(results, "distinct_average") do
  session.get("/notes/statistics")
  JSON.parse(session.response.body).fetch("average_title_length")
end
observe(results, "grouped_update") do
  session.post("/notes/#{Note.order(:id).first.id}/archive")
  raise "Archive request failed" unless session.response.status == 204
  Note.where(archived: true).count
end
observe(results, "bulk_deprecation") do
  warnings = []
  deprecator = ActiveRecord.respond_to?(:deprecator) ? ActiveRecord.deprecator : ActiveSupport::Deprecation
  old = deprecator.behavior
  begin
    deprecator.behavior = ->(message, *) { warnings << message }
    session.post("/notes/publish")
    raise "Publication request failed" unless session.response.status == 204
  ensure
    deprecator.behavior = old
  end
  warnings.any? { |message| message.include?("distinct") && message.include?("8.2") }
end
observe(results, "delete_multi") do
  Rails.cache.write("expired", 1)
  NotebookWorkflows.expire_exports(["expired"].freeze)
end
observe(results, "head_after_render") do
  session.get("/preview.json")
  status = session.response.status
  exception = nil
  original = Rails.application.env_config["action_dispatch.show_exceptions"]
  begin
    Rails.application.env_config["action_dispatch.show_exceptions"] = Rails::VERSION::MAJOR >= 8 ? :none : false
    session.get("/preview.json")
  rescue AbstractController::DoubleRenderError => error
    exception = error.class.name
  ensure
    Rails.application.env_config["action_dispatch.show_exceptions"] = original
  end
  { "status" => status, "exception" => exception }
end

observe(results, "sql_boolean") { [true, false].map { |value| NotebookWorkflows.sql_boolean(value) } }
observe(results, "nested_isolation") { NotebookWorkflows.isolated_export(connection) }
observe(results, "serializer_precedence") do
  session.get("/exports/manifest", params: { destination: "archive" })
  JSON.parse(session.response.body).fetch("format")
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
observe(results, "quoted_literal_control") { connection.select_value("SELECT 'literal'") }
observe(results, "strong_params_control") do
  ActionController::Parameters.new(note: { title: "a", extra: "b" }).require(:note).permit(:title).to_h
end
observe(results, "sse_control") do
  Note.delete_all
  Note.create!(title: "stream")
  session.get("/stream")
  session.response.body
end
observe(results, "job_zone") do
  session.post("/exports", params: { export: {
    title: "zone", amount: "1.25", deadline: "2020-01-01 00:00:00", time_zone: "Asia/Tokyo"
  } })
  raise "Export creation failed" unless session.response.status == 201
  Note.find_by!("title = ?", "zone").metadata.fetch("deadline")
end
observe(results, "json_escape_control") do
  ActiveSupport::JSON.encode({ "text" => "line\u2028break" }).include?("\\u2028")
end

observe(results, "caption_alias") { Note.new(title: "Example").caption }
observe(results, "legacy_label") { ExportPreferences.label }
observe(results, "global_timezone") { ExportPreferences.timezone.to_s }
observe(results, "global_warning") { ExportPreferences.warn_legacy_format }
observe(results, "nil_form") do
  ExportPreferences.note_form(NotesController.new.view_context).include?('name="note[title]"')
end
observe(results, "retry_wait") do
  original = ExportJob.queue_adapter
  begin
    ExportJob.queue_adapter = :test
    session.post("/exports", params: { export: {
      title: "offline", amount: "1.25", deadline: "2020-01-01T00:00:00Z"
    } })
    raise "Retry export submission failed" unless session.response.status == 201
    ExportJob.execute(ExportJob.queue_adapter.enqueued_jobs.shift)
    ExportJob.queue_adapter.enqueued_jobs.size
  ensure
    ExportJob.queue_adapter = original
  end
end
observe(results, "exception_policy") do
  session.get("/notes/99999")
  session.response.status
end

# Boot/CRUD checks are prerequisites, not extra counted upgrade issues.
session.get("/health")
raise "Health endpoint failed" unless session.response.status == 200 && JSON.parse(session.response.body) == { "status" => "ok" }
session.post("/notes", params: { note: { title: "boot" } })
raise "Note creation failed" unless session.response.status == 302 && Note.where(title: "boot").count == 1
session.get("/notes.json")
body = JSON.parse(session.response.body)
raise "Jbuilder listing failed" unless session.response.status == 200 && body.fetch("notes").size == 3
results["runtime"] = {
  "ruby" => RUBY_VERSION,
  "gems" => %w[rails puma rack pg redis].to_h { |gem| [gem, Gem.loaded_specs.fetch(gem).version.to_s] },
  "postgresql_server" => connection.select_value("SHOW server_version"),
  "redis_server" => Rails.cache.redis.with { |redis| redis.info("server").fetch("redis_version") }
}
puts JSON.generate(results)
