apply "config/application.rb"

remove_file "config/secrets.yml"

template "config/initializers/generators.rb.tt", ".config/initializers/generators.rb", force: true

if %w[sqlite3 mysql].include?(options[:database])
  copy_file "config/initializers/uuid_rails.rb"
  copy_file "config/initializers/types.rb"
end

apply "config/environments/development.rb"
apply "config/environments/production.rb"
apply "config/environments/test.rb"

# docker run --rm --detach --name postgres-container -p 5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust -d postgres:14.10
if options[:database] == "postgresql"
  insert_into_file "config/database.yml", <<-RUBY, before: "development:"
  username: postgres
  password:
  host: localhost
  port: 5432

  RUBY
  # uncomment_lines "config/database.yml", /host: localhost/
  # uncomment_lines "config/database.yml", /port: 5432/
end

# docker run --rm --name mysql-container --publish 3308:3306 --env MYSQL_ALLOW_EMPTY_PASSWORD=yes -d mysql:latest
if options[:database] == "mysql"
  insert_into_file "config/database.yml", <<-RUBY, before: "development:"
  port: 3308

  RUBY

  gsub_file "config/database.yml", /localhost/ do |_match|
    "0.0.0.0"
  end
end
