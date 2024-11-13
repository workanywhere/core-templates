require "thor"

module PostCreation
  module Process
    class Cmd < Thor
      def self.exit_on_failure?
        false
      end

      include Thor::Actions

      namespace "update"

      desc "app", "Run script to update the app"

      # bundle exec thor update:app
      def app
        adapter_name = `rails runner 'puts ActiveRecord::Base.connection.adapter_name'`

        run("rails g scaffold user name:string --force")

        # Due to trailing whitespace in the Rails service-worker.js file, we need to skip the TrailingWhitespace hook
        run "sed -i '' 's/[ \t]*$//' app/views/pwa/service-worker.js"
        # Those line will be removed in the future, once the trailing whitespace is fixed in the Rails service-worker.js file

        commit "Add scaffold user"

        run("rails g scaffold post title:string body:text user:references --force")
        commit "Add scaffold post"

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/posts_controller.rb.patch")
        commit "Update posts controller"

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/user.rb.patch")
        commit "Update user model"

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/_post_partial.html.erb.patch")
        commit "Update post partial"

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/post_form.erb.patch")
        commit "Update post form partial"

        if adapter_name !~ /PostgreSQL/
          run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/post_model.rb.patch")
          commit "Update post model"
        end

        append_to_file "db/seeds.rb", <<~RUBY
          user = User.find_or_create_by!(name: "John Doe")
          Post.find_or_create_by!(title: "Hello World", body: "This is a test post", user: user)
        RUBY
        commit "Seed content"

        if adapter_name =~ /Mysql2/
          current_directory_name = File.basename(Dir.pwd)
          say "Creating MySQL databases for #{current_directory_name}_development and #{current_directory_name}_test"
          run("docker exec mysql-container bash -c \"mysql -u root -e 'CREATE DATABASE IF NOT EXISTS #{current_directory_name}_development;'\"")
          run("docker exec mysql-container bash -c \"mysql -u root -e 'CREATE DATABASE IF NOT EXISTS #{current_directory_name}_test;'\"")
          run("db:migrate db:seed db:schema:dump")
        else
          run("rails db:drop db:create db:migrate db:seed")
        end
        commit "Updated Schema"

        say("Adding foreman to the Gemfile")
        run("bundle add foreman")
        commit "Add foreman to the Gemfile"

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git apply patches/fix_test_suite.patch")
        commit "Fix Test Suite"

        insert_into_file "app/models/post.rb", "  validates :title, presence: true\n", :after => "belongs_to :user\n"
        commit "Add validation to post model"

        if adapter_name !~ /PostgreSQL/
          insert_into_file "app/models/post.rb", "  attribute :user_id, :uuid_v7\n", :after => "belongs_to :user\n"
          commit "Declare Foreign Key Type"
        end

        run("mkdir -p spec/system")
        run("cp -v patches/posts_spec.rb spec/system/posts_spec.rb")
        commit "Add posts system spec"

        if adapter_name =~ /PostgreSQL/
          say("DB_PORT=5433 bin/dev")
        else
          say("bin/dev")
        end
      end

      private

      def commit(message)
        run("rubocop -A", capture: true)
        run("rubocop --regenerate-todo", capture: true)

        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate overcommit --run")
        run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git add .")

        if run_with_clean_bundler_env("SKIP=RailsSchemaUpToDate git commit -m '#{message}'")
          puts "✅ Git commit successful."
        else
          puts "❌ Git commit failed."
        end
      end

      def run_with_clean_bundler_env(cmd)
        success = if defined?(Bundler)
                    Bundler.with_original_env { run(cmd) }
                  else
                    run(cmd)
                  end

        return true if success

        puts "Command failed, exiting: #{cmd}"
        exit(1)
      end
    end
  end
end
