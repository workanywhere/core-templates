insert_into_file "config/application.rb", <<-RUBY, before: "  end"

    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
    config.log_level = :debug

    config.active_record.schema_format = :ruby # :sql

RUBY

# mysqldump does not work with docker
#
# mysqldump: Got error: 1045: Access denied for user 'root'@'192.168.65.1' (using password: YES) when trying to connect
# bin/rails aborted!
# failed to execute: `mysqldump`
# Please check the output above for any errors and make sure that `mysqldump` is installed in your PATH and has proper permissions.

if options[:database] == "mysql"
    insert_into_file "config/application.rb", <<-RUBY, before: "  end"
        config.active_record.dump_schema_after_migration = false
    RUBY
end

comment_lines "config/application.rb", /config\.generators\.system_tests = nil/