apply "config/application.rb"

remove_file "config/secrets.yml"

copy_file "config/initializers/generators.rb"
copy_file "config/initializers/ulid_rails.rb"

apply "config/environments/development.rb"
apply "config/environments/production.rb"
apply "config/environments/test.rb"
