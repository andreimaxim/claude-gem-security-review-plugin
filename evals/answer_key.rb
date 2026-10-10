# Frozen rubric v1: Rails 8.0.5 -> 8.1.4, retaining load_defaults 7.0.
# One root cause per row; controls and repetitions never increase the issue count.
ROWS = [
  ["sqlite_cast", "activerecord", "SQLite result casting now uses declared column types", "app/services/notebook_workflows.rb", "String", "Time", "activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb", "ActiveRecord::Result.new"],
  ["long_key", "activesupport", "Key truncation prevents suffix-pattern export invalidation", "app/services/notebook_workflows.rb", nil, "export", "activesupport/lib/active_support/cache.rb", "def normalize_key"],
  ["sse_batch", "actionpack", "SSE changes event write boundaries from multiple writes to one", "app/controllers/streams_controller.rb", 3, 1, "actionpack/lib/action_controller/metal/live.rb", "def perform_write"],
  ["stream_buffer", "actionpack", "Stream write copies mutable strings and returns byte count", "app/services/notebook_workflows.rb", {"return" => "Array", "body" => "changed"}, {"return" => "Integer", "body" => "é", "bytes" => 2}, "actionpack/lib/action_dispatch/http/response.rb", "def write"],
  ["parameter_encoding", "actionpack", "Invalid parameter-name encoding now rejected by parser", "app/controllers/notes_controller.rb", false, {"error" => "ActionController::BadRequest"}, "actionpack/lib/action_dispatch/http/param_builder.rb", "valid_encoding?"],
  ["limit", "activerecord", "Export limit validated at relation construction instead of execution", "app/models/note.rb", "ActiveRecord::Relation", {"error" => "ArgumentError"}, "activerecord/lib/active_record/relation/query_methods.rb", "def limit!"],
  ["distinct_average", "activerecord", "Distinct averages now actually deduplicate aggregate input", "app/models/note.rb", 2.3333333333333335, 3.0, "activerecord/lib/active_record/relation/calculations.rb", "operation == \"average\""],
  ["grouped_update", "activerecord", "Grouped bulk archive respects HAVING rather than updating all rows", "app/models/note.rb", 3, 1, "activerecord/lib/arel/visitors/to_sql.rb", "prepare_update_statement"],
  ["bulk_deprecation", "activerecord", "Distinct bulk publication now warns about unsupported scope for 8.2", "app/models/note.rb", false, true, "activerecord/lib/active_record/relation.rb", "def update_all"],
  ["delete_multi", "activesupport", "Multi-key deletion no longer mutates the caller's frozen array", "app/services/notebook_workflows.rb", {"error" => "FrozenError"}, 1, "activesupport/lib/active_support/cache.rb", "def delete_multi"],
  ["head_after_render", "actionpack", "Preview's head after Jbuilder render now raises double-render error", "app/controllers/notes_controller.rb", 200, {"error" => "AbstractController::DoubleRenderError"}, "actionpack/lib/action_controller/metal/head.rb", "def head"],
  ["sql_boolean", "activerecord", "SQLite SQL export changes quoted boolean representation", "app/services/notebook_workflows.rb", ["1", "0"], ["TRUE", "FALSE"], "activerecord/lib/active_record/connection_adapters/sqlite3/quoting.rb", "quoted_true"],
  ["nested_isolation", "activerecord", "Nested transactions accept matching explicit isolation", "app/services/notebook_workflows.rb", {"error" => "ActiveRecord::TransactionIsolationError"}, 3, "activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb", "def transaction"],
  ["serializer_precedence", "activejob", "Exact-class serializer registration changes precedence", "app/jobs/export_destination.rb", "legacy", "current", "activejob/lib/active_job/serializers.rb", "def serialize"],
  ["duration_precision", "activesupport", "Fractional duration conversion preserves precision", "app/services/notebook_workflows.rb", 1.5, 1.5083333333333333, "activesupport/lib/active_support/duration.rb", "def in_minutes"],
  ["frozen_advance", "activesupport", "Time advance accepts frozen fractional-day options", "app/services/notebook_workflows.rb", {"error" => "FrozenError"}, "2020-01-02T12:00:00Z", "activesupport/lib/active_support/core_ext/time/calculations.rb", "def advance"],
  ["indifferent_filter", "activesupport", "Indifferent hash filtering preserves symbol lookup", "app/services/notebook_workflows.rb", nil, "Ada", "activesupport/lib/active_support/hash_with_indifferent_access.rb", "filter"],
  ["blank_locale", "actionpack", "Blank optional route segment is omitted", "app/controllers/notes_controller.rb", "/locale//products/123", "/products/123", "actionpack/lib/action_dispatch/journey/formatter.rb", "def generate"],
  ["http_date", "actionpack", "Conditional request accepts RFC850 HTTP dates", "app/controllers/notes_controller.rb", 200, 304, "actionpack/lib/action_dispatch/http/cache.rb", "httpdate"],
  ["nil_separator", "activesupport", "Parameterize accepts nil separator", "app/services/notebook_workflows.rb", {"error" => "TypeError"}, "donaldeknuth", "activesupport/lib/active_support/inflector/transliterate.rb", "def parameterize"],
].freeze

issues = ROWS.each_with_index.map do |(probe, gem, title, location, baseline, target, source, anchor), index|
  { "id" => format("U%03d", index + 1), "probe" => probe, "gem" => gem,
    "title" => title, "location" => location, "baseline" => baseline, "target" => target,
    "source" => source, "anchor" => anchor, "verification" => "executable",
    "severity" => %w[sqlite_cast sse_batch stream_buffer limit bulk_deprecation delete_multi sql_boolean serializer_precedence].include?(probe) ? "integration-review" : "behavior-change" }
end

ANSWER_KEY = {
  "version" => 1, "requested_positive_count" => 20, "status" => "complete",
  "baseline_rails" => "8.0.5", "target_rails" => "8.1.4", "ruby" => "3.4.7", "defaults" => "7.0",
  "issues" => issues,
  "controls" => [
    { "id" => "C001", "probe" => "cache_format_control", "title" => "Retained defaults preserve 7.0 cache format", "baseline" => 7.0, "target" => 7.0, "source" => "railties/lib/rails/application/configuration.rb", "anchor" => "cache_format_version" },
    { "id" => "C002", "probe" => "strict_sqlite_control", "title" => "Strict SQLite strings remain opt-in", "baseline" => "literal", "target" => "literal", "source" => "activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb", "anchor" => "SQLite3Adapter" },
    { "id" => "C003", "probe" => "strong_params_control", "title" => "require/permit remains supported", "baseline" => {"title" => "a"}, "target" => {"title" => "a"}, "source" => "actionpack/lib/action_controller/metal/strong_parameters.rb", "anchor" => "def require" },
    { "id" => "C004", "probe" => "sse_control", "title" => "Concatenated SSE protocol bytes remain unchanged", "baseline" => "event: notes\nid: latest\ndata: {\"count\":1}\n\n", "target" => "event: notes\nid: latest\ndata: {\"count\":1}\n\n", "source" => "actionpack/lib/action_controller/metal/live.rb", "anchor" => "def perform_write" },
    { "id" => "C005", "probe" => "job_zone_control", "title" => "Inline job serialization preserves timezone at both endpoints", "baseline" => "Asia/Tokyo", "target" => "Asia/Tokyo", "source" => "activejob/lib/active_job/serializers/time_with_zone_serializer.rb", "anchor" => "def deserialize" },
    { "id" => "C006", "probe" => "json_escape_control", "title" => "8.1 JSON escaping default not activated by retained 7.0 defaults", "baseline" => true, "target" => true, "source" => "railties/lib/rails/application/configuration.rb", "anchor" => "when \"8.1\"" },
    { "id" => "C007", "probe" => "local_cache", "title" => "Ordinary MemoryStore reads still see concurrent updates despite new middleware", "baseline" => ["old", "new"], "target" => ["old", "new"], "source" => "activesupport/lib/active_support/cache/memory_store.rb", "anchor" => "def read_entry" }
  ]
}.freeze
