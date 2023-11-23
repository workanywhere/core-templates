apply "config/application.rb"

remove_file "config/secrets.yml"

gsub_file "config/routes.rb", /  # root 'welcome#index'/ do
  '  root "home#index"'
end

copy_file "config/initializers/generators.rb"

apply "config/environments/development.rb"
apply "config/environments/production.rb"
apply "config/environments/test.rb"

route 'root "home#index"'
route %Q(mount Sidekiq::Web => "/sidekiq" if defined?(Sidekiq) # monitoring console\n)
