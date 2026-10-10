require_relative "boot"
require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"
Bundler.require(*Rails.groups)

module MarginNotes
  class Application < Rails::Application
    config.load_defaults 7.0
    config.api_only = true
    config.eager_load = false
    config.secret_key_base = "local-margin-notes-development-" * 4
    config.hosts.clear
    config.cache_store = :memory_store, { namespace: "notebook" }
    config.active_job.queue_adapter = :inline
    config.action_dispatch.show_exceptions = :none
    config.active_support.deprecation = :stderr
    config.i18n.available_locales = [:en, :fr]
    config.logger = ActiveSupport::Logger.new($stderr)
  end
end
