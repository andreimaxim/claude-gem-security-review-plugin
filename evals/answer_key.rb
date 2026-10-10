# Frozen Rails 7.0.8.7 -> 8.1.4 corpus. One distinct root cause per row.
# Target observations are taken before each root cause's repair, after the
# documented boot prerequisites. Controls and repetitions do not add issues.
BOOT_ROWS = [
  ["puma_rack", "rails", "Puma 5 rejects the Rack 3 stack", "Gemfile", "StandardError", "Puma 5 is not compatible with Rack 3", "02-puma.patch", nil, nil],
  ["enum_syntax", "activerecord", "Keyword-only enum declarations are removed", "app/models/note.rb", "ArgumentError", "given 0, expected 1..2", "03-enum.patch", "activerecord/lib/active_record/enum.rb", "def enum"],
  ["positional_coder", "activerecord", "Metadata coder must be a keyword argument", "app/models/note.rb", "ArgumentError", "given 2, expected 1", "04-serialize.patch", "activerecord/lib/active_record/attribute_methods/serialization.rb", "def serialize"],
  ["partial_writes", "activerecord", "Combined partial_writes accessor is removed", "app/models/note.rb", "NoMethodError", "partial_writes=", "05-partial-writes.patch", "activerecord/lib/active_record/attribute_methods/dirty.rb", "partial_updates"],
  ["virtual_enum", "activerecord", "Virtual delivery enum needs an explicit attribute type", "app/models/note.rb", "RuntimeError", "Undeclared attribute type", "06-virtual-enum.patch", "activerecord/lib/active_record/enum.rb", "EnumType"],
  ["method_alias", "activerecord", "Attribute aliases cannot target ordinary methods", "app/models/note.rb", "ArgumentError", "is not an attribute", "07-method-alias.patch", "activerecord/lib/active_record/attribute_methods.rb", "alias_attribute"],
].freeze

ROWS = [
  ["long_key", "activesupport", "Shorter Redis cache keys discard export invalidation suffixes", "app/services/notebook_workflows.rb", nil, "export", "activesupport/lib/active_support/cache.rb", "def normalize_key"],
  ["sse_batch", "actionpack", "SSE batches a logical event into one write", "app/controllers/streams_controller.rb", 3, 1, "actionpack/lib/action_controller/metal/live.rb", "def perform_write"],
  ["stream_buffer", "actionpack", "Stream writes copy mutable buffers and return byte counts", "app/services/notebook_workflows.rb", {"return" => "Array", "body" => "changed"}, {"return" => "Integer", "body" => "é", "bytes" => 2}, "actionpack/lib/action_dispatch/http/response.rb", "def write"],
  ["limit", "activerecord", "Export limit validation moves to relation construction", "app/models/note.rb", "ActiveRecord::Relation", {"error" => "ArgumentError"}, "activerecord/lib/active_record/relation/query_methods.rb", "def limit!"],
  ["distinct_average", "activerecord", "Distinct averages deduplicate title lengths", "app/models/note.rb", 2.3333333333333335, 3.0, "activerecord/lib/active_record/relation/calculations.rb", "operation == \"average\""],
  ["grouped_update", "activerecord", "Bulk archiving now respects grouped HAVING predicates", "app/models/note.rb", 3, 1, "activerecord/lib/arel/visitors/to_sql.rb", "prepare_update_statement"],
  ["bulk_deprecation", "activerecord", "Unsupported distinct bulk publication warns about Rails 8.2", "app/models/note.rb", false, true, "activerecord/lib/active_record/relation.rb", "def update_all"],
  ["delete_multi", "activesupport", "Multi-key expiry accepts frozen caller arrays", "app/services/notebook_workflows.rb", {"error" => "FrozenError"}, 1, "activesupport/lib/active_support/cache.rb", "def delete_multi"],
  ["head_after_render", "actionpack", "Preview double rendering becomes an error response", "app/controllers/notes_controller.rb", {"status" => 200, "exception" => nil}, {"status" => 500, "exception" => "AbstractController::DoubleRenderError"}, "actionpack/lib/action_controller/metal/head.rb", "def head"],
  ["nested_isolation", "activerecord", "Nested export transactions accept matching isolation", "app/services/notebook_workflows.rb", {"error" => "ActiveRecord::TransactionIsolationError"}, 3, "activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb", "def transaction"],
  ["serializer_precedence", "activejob", "Exact-class serializer precedence changes the outbound format", "app/jobs/export_destination.rb", "legacy", "current", "activejob/lib/active_job/serializers.rb", "def serialize"],
  ["duration_precision", "activesupport", "Elapsed-minute conversion retains fractional seconds", "app/services/notebook_workflows.rb", 1.5, 1.5083333333333333, "activesupport/lib/active_support/duration.rb", "def in_minutes"],
  ["frozen_advance", "activesupport", "Deadline advancement accepts frozen fractional options", "app/services/notebook_workflows.rb", {"error" => "FrozenError"}, "2020-01-02T12:00:00Z", "activesupport/lib/active_support/core_ext/time/calculations.rb", "def advance"],
  ["indifferent_filter", "activesupport", "Filtered author metadata retains symbol lookup", "app/services/notebook_workflows.rb", nil, "Ada", "activesupport/lib/active_support/hash_with_indifferent_access.rb", "filter"],
  ["blank_locale", "actionpack", "Blank locale routing omits the empty segment", "app/controllers/notes_controller.rb", "/locale//products/123", "/products/123", "actionpack/lib/action_dispatch/journey/formatter.rb", "def generate"],
  ["http_date", "actionpack", "Conditional requests recognize RFC850 dates", "app/controllers/notes_controller.rb", 200, 304, "actionpack/lib/action_dispatch/http/cache.rb", "httpdate"],
  ["nil_separator", "activesupport", "Export parameterization accepts a nil separator", "app/services/notebook_workflows.rb", {"error" => "TypeError"}, "donaldeknuth", "activesupport/lib/active_support/inflector/transliterate.rb", "def parameterize"],
  ["job_zone", "activejob", "Export job serialization retains the caller's timezone", "app/jobs/export_job.rb", "UTC", "Asia/Tokyo", "activejob/lib/active_job/serializers/time_with_zone_serializer.rb", "def deserialize"],
  ["caption_alias", "activerecord", "Attribute aliases bypass the overridden display reader", "app/models/note.rb", "Note: Example", "Example", "activerecord/lib/active_record/attribute_methods.rb", "alias_attribute"],
  ["legacy_label", "rails", "Application secrets accessor is removed", "app/services/export_preferences.rb", "Margin Notes", {"error" => "NoMethodError"}, "railties/lib/rails/application.rb", "def credentials"],
  ["global_timezone", "activerecord", "Global settings delegation through ActiveRecord::Base is removed", "app/services/export_preferences.rb", "utc", {"error" => "NoMethodError"}, "activerecord/lib/active_record/core.rb", "default_timezone"],
  ["global_warning", "activesupport", "Global deprecation singleton delegation is removed", "app/services/export_preferences.rb", "CSV v1", {"error" => "NoMethodError"}, "activesupport/lib/active_support/deprecation.rb", "class Deprecation"],
  ["nil_form", "actionview", "Compose form rejects an explicitly nil model", "app/services/export_preferences.rb", true, {"error" => "ArgumentError"}, "actionview/lib/action_view/helpers/form_helper.rb", "def form_with"],
  ["retry_wait", "activejob", "Exponentially_longer retry selector is removed", "app/jobs/export_job.rb", 1, {"error" => "RuntimeError"}, "activejob/lib/active_job/exceptions.rb", "determine_delay"],
  ["exception_policy", "actionpack", "Boolean false no longer means propagate request exceptions", "config/application.rb", {"error" => "ActiveRecord::RecordNotFound"}, 404, "actionpack/lib/action_dispatch/middleware/show_exceptions.rb", "show_exceptions?"],
].freeze

issues = BOOT_ROWS.each_with_index.map do |(probe, gem, title, location, error, message, repair, source, anchor), index|
  { "id" => format("U%03d", index + 1), "probe" => probe, "gem" => gem, "title" => title,
    "location" => location, "baseline" => "ready", "target" => {"error" => error},
    "target_message" => message, "repair_patch" => "patches/stages/#{repair}",
    "source" => source, "anchor" => anchor, "severity" => "boot-blocker" }
end
issues.first["external_evidence"] = [
  { "repository" => "puma/puma", "tag" => "v5.6.9", "file" => "lib/puma.rb" },
  { "repository" => "puma/puma", "tag" => "v5.6.9", "file" => "lib/rack/version_restriction.rb" },
  { "repository" => "puma/puma", "tag" => "v6.6.1", "file" => "lib/puma.rb" }
]
issues += ROWS.each_with_index.map do |(probe, gem, title, location, baseline, target, source, anchor), index|
  { "id" => format("U%03d", index + BOOT_ROWS.size + 1), "probe" => probe, "gem" => gem,
    "title" => title, "location" => location, "baseline" => baseline, "target" => target,
    "source" => source, "anchor" => anchor,
    "severity" => %w[sse_batch stream_buffer limit bulk_deprecation serializer_precedence].include?(probe) ? "integration-review" : "behavior-change" }
end
issues.each do |item|
  case item["probe"]
  when "method_alias", "caption_alias"
    item["external_evidence"] = [
      { "repository" => "rails/rails", "tag" => "v7.0.8.7", "file" => "activemodel/lib/active_model/attribute_methods.rb" },
      { "repository" => "rails/rails", "tag" => "v8.1.4", "file" => "activerecord/lib/active_record/attribute_methods/read.rb" }
    ]
  when "exception_policy"
    item["external_evidence"] = %w[v7.0.8.7 v8.1.4].map do |tag|
      { "repository" => "rails/rails", "tag" => tag, "file" => "actionpack/lib/action_dispatch/middleware/exception_wrapper.rb" }
    end
  when "global_warning"
    item["external_evidence"] = [
      { "repository" => "rails/rails", "tag" => "v7.0.8.7", "file" => "activesupport/lib/active_support/deprecation/instance_delegator.rb" }
    ]
  end
end

CONTROL_ROWS = [
  ["timestamp_cast", "PostgreSQL timestamp exports are typed at both endpoints", "Time", "activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb", "def query"],
  ["parameter_encoding", "Malformed parameter names are rejected at both endpoints", {"error" => "ActionController::BadRequest"}, "actionpack/lib/action_dispatch/http/request.rb", "query_parameters"],
  ["sql_boolean", "PostgreSQL boolean SQL tokens retain their representation", ["TRUE", "FALSE"], "activerecord/lib/active_record/connection_adapters/abstract/quoting.rb", "quoted_true"],
  ["cache_format_control", "Retained defaults preserve cache format 7.0", 7.0, "railties/lib/rails/application/configuration.rb", "cache_format_version"],
  ["quoted_literal_control", "PostgreSQL single-quoted SQL literals remain supported", "literal", "activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb", "def quote"],
  ["strong_params_control", "require/permit still filters unpermitted values", {"title" => "a"}, "actionpack/lib/action_controller/metal/strong_parameters.rb", "def require"],
  ["sse_control", "Concatenated SSE bytes remain stable", "event: notes\nid: latest\ndata: {\"count\":1}\n\n", "actionpack/lib/action_controller/metal/live.rb", "def perform_write"],
  ["json_escape_control", "JSON continues escaping Unicode line separators", true, "activesupport/lib/active_support/json/encoding.rb", "2028"],
  ["local_cache", "Request-local Redis reads retain the cached value despite an external update", ["old", "old"], "activesupport/lib/active_support/cache/strategy/local_cache.rb", "LocalStore"]
].freeze

ANSWER_KEY = {
  "version" => 2, "requested_positive_count" => 31, "status" => "complete",
  "baseline_rails" => "7.0.8.7", "target_rails" => "8.1.4", "ruby" => "3.2.9", "defaults" => "7.0",
  "issues" => issues,
  "controls" => CONTROL_ROWS.each_with_index.map do |(probe, title, expected, source, anchor), index|
    { "id" => format("C%03d", index + 1), "probe" => probe, "title" => title,
      "location" => "app/services/notebook_workflows.rb", "baseline" => expected, "target" => expected,
      "source" => source, "anchor" => anchor }
  end
}.freeze
