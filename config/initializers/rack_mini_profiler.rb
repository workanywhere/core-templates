# frozen_string_literal: true

if Rails.env.development?
  require "rack-mini-profiler"

  # The initializer was required late, so initialize it manually.
  Rack::MiniProfilerRails.initialize!(Rails.application)

  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore

  # Do not let rack-mini-profiler disable caching
  # Rack::MiniProfiler.config.disable_caching = false # defaults to true
end
