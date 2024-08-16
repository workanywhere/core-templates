# frozen_string_literal: true

require 'thor'

module PostCreation
  module DeploymentConfiguration
    class Cmd < Thor
      def self.exit_on_failure?
        false
      end

      include Thor::Actions

      namespace 'deployment'

      desc 'configuration', 'Run script to configure the deployment'

      # bundle exec thor deployment:configuration
      def configuration
        say 'Checking if dokku is installed'
        current_app_name = File.basename(Dir.pwd)
        inside '~' do
          if run("DOKKU_HOST=dokku.me dokku apps:list | grep #{current_app_name}")
            say "App #{current_app_name} already exists"
            exit
          end
        end

        say "Creating dokku app #{current_app_name}"
        run("ssh workanywhere.app 'dokku apps:create #{current_app_name}'")

        say 'Adding dokku remote'
        run("git remote add dokku dokku@dokku.me:#{app_name}")

        say "Creating dokku postgresql database #{app_name}-db"
        run("dokku postgres:create #{app_name}-db")

        say "Linking dokku postgresql database #{app_name}-db to #{app_name}"
        run("dokku postgres:link #{app_name}-db")

        rails_master_key = `cat config/master.key`
        say 'Setting RAILS_MASTER_KEY'
        run("dokku config:set RAILS_MASTER_KEY=#{rails_master_key}")

        say 'Disabling checks for first deployment'
        run('dokku checks:disable web')

        say 'Deploying to dokku'
        run_with_clean_bundler_env('git push dokku main')

        say 'Enabling checks for zero downtime deployment'
        run('dokku checks:enable web')

        say 'Setting domain'
        run("dokku domains:set #{app_name}.workanywhere.app")

        say 'Setting port'
        run('dokku ports:set http:80:3000')

        say 'Enabling letsencrypt'
        run('dokku letsencrypt:enable')

        say 'Restarting app'
        run('dokku ps:restart')
      end

      private

      def current_directory_name
        @current_directory_name ||= File.basename(Dir.pwd)
      end
      alias app_name current_directory_name

      def run_with_clean_bundler_env(cmd)
        success = if defined?(Bundler)
                    if Bundler.respond_to?(:with_original_env)
                      Bundler.with_original_env { run(cmd) }
                    else
                      Bundler.with_clean_env { run(cmd) }
                    end
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
