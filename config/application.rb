insert_into_file "config/application.rb", <<-RUBY, before: "  end"

    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
    config.log_level = :debug

RUBY
