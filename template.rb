require "bundler"
require "json"

RAILS_REQUIREMENT = "~> 7.2.0".freeze
# RAILS_REQUIREMENT = "~> 7.0.8".freeze
RUBY_VERSION = "3.3.4".freeze

# rails _7.1.2_ new my-app-1 --database=sqlite3 --css=tailwind --javascript=importmap --skip-jbuilder --skip-test --template ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb
# rails _7.1.2_ new my-app-1 --skip-test -m ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb
# rails _7.0.8_ new my-app-1 --skip-jbuilder --skip-test -m ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  self.options = options.reverse_merge(
    css: "tailwind",
    javascript: "importmap",
    asset_pipeline: "propshaft",
    skip_jbuilder: true,
    skip_system_test: true,
    skip_test: true,
    skip_test_unit: true
  )

  assert_valid_options

  %w[
    bundler-audit
    erb_lint
    rubocop
    rubocop-performance
    rubocop-rake
    rubocop-rspec
    rubocop-rspec_rails
    rubocop-gitlab-security
    rubocop-capybara
    rubocop-factory_bot
    overcommit
  ].each do |tool|
    run("gem install #{tool}")
  end

  git :init unless preexisting_git_repo?
  git_commit "Initial commit"

  template "Gemfile.tt", force: true
  git_commit "Add Gemfile"

  template "example.env.tt"
  git_commit "Add example.env"

  copy_file "editorconfig", ".editorconfig"
  git_commit "Add .editorconfig"

  copy_file "erb-lint.yml", ".erb-lint.yml"
  git_commit "Add .erb-lint.yml"

  template "ruby-version.tt", ".ruby-version", force: true
  git_commit "Add .ruby-version"

  copy_file "Thorfile"
  git_commit "Add Thorfile"
  copy_file "Procfile"
  git_commit "Add Procfile"
  copy_file "app.json"
  git_commit "Add Dokku Deployment Tasks Configuration"

  apply "Rakefile.rb"
  git_commit "Add Rakefile"
  apply "bin/bins.rb"
  git_commit "Add bin files"
  apply "github/template.rb"
  git_commit "Add GitHub templates"
  apply "config/template.rb"
  run_rubocop_autocorrections
  git_commit "Add config"
  apply "lib/tasks.rb"
  git_commit "Add tasks"
  apply "lib/templates.rb"
  run_rubocop_autocorrections
  git_commit "Add templates"

  # Make sure the templates are NOT loaded.
  # Ideally template files should get the extension .tt, so there are ignored by default.
  # Unfortunately it is not always the case so we have to make sure the directory is safely ignored by the loader.
  gsub_file "config/application.rb", /config\.autoload_lib\(ignore: %w\[assets tasks\]\)/, "config.autoload_lib(ignore: %w[assets tasks templates])"
  git_commit "Ignore templates"

  empty_directory_with_keep_file "app/lib"

  empty_directory ".git/safe"

  run("bundle install")
  git_commit "Run bundle install"

  run("rails generate rspec:install")
  git_commit "Add RSpec"

  apply "spec/template.rb"
  git_commit "Add RSpec Support templates"

  if %w[sqlite3 mysql].include?(options[:database])
    run("rails generate uuid_v7:install")
    git_commit "Add Uuid_v7 initializer"

    run("rails generate uuid_v7:migrations --force")
    git_commit "Add Uuid_v7 migrations"
  end

  append_to_file ".gitignore", <<~IGNORE

    # Ignore application config.
    /.env.development
    /.env.*local

    # Ignore locally-installed gems.
    /vendor/bundle/
  IGNORE
  git_commit "Ignore application config and locally-installed gems"

  create_database_and_initial_migration
  git_commit "Create database and initial migration"

  run_with_clean_bundler_env "bin/setup"
  git_commit "Run bin/setup"

  run "overcommit --install" # if overcommit_present?
  copy_file "overcommit.yml", ".overcommit.yml", force: true
  run("overcommit --sign")
  git_commit "Add .overcommit.yml"

  binstubs = %w[bundler bundler-audit erb_lint rubocop thor brakeman]
  binstubs.each do |binstub|
    run_with_clean_bundler_env "bundle binstubs #{binstub} --force"
    git_commit "Install binstub for #{binstub}"
  end

  copy_file "rubocop.yml", ".rubocop.yml", force: true
  git_commit "Add .rubocop.yml"

  run "rails generate controller Welcome home"
  gsub_file "config/routes.rb", 'root "posts#index"', 'root "welcome#home"'
  git_commit "Generate Welcome controller"

  copy_dir "patches", "patches"
  git_commit "Add patches"

  run "bundle exec thor update:app"

  return unless changes_to_commit?

  git checkout: "-b main"
  git add: "-A ."
  git commit: "-n -m 'Set up project'"
  return unless git_repo_specified?

  git remote: "add origin #{git_repo_url.shellescape}"
  git push: "-u origin --all"
end

require "fileutils"
require "shellwords"

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("rails-template-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/joel/rails-template.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{rails-template/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def assert_minimum_rails_version
  requirement   = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)

  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. " \
           "You are using #{rails_version}. Continue anyway?"

  exit 1 if no?(prompt)
end

# Bail out if user has passed in contradictory generator options.
def assert_valid_options
  valid_options = {
    "skip_namespace" => false,
    "skip_collision_check" => false,
    "asset_pipeline" => "propshaft",
    "api" => false,
    "javascript" => "importmap",
    "css" => "tailwind",
    "skip_jbuilder" => true,
    "skip_test" => true
  }

  valid_options.each do |key, expected|
    actual = options[key]

    raise Rails::Generators::Error, "\nMissing option: #{key}=#{expected}" if actual.nil?

    raise Rails::Generators::Error, "Unsupported option: #{key}=#{actual}" unless actual == expected
  end
end

def git_repo_url
  @git_repo_url ||=
    ask_with_default("What is the git remote URL for this project?", :blue, "skip")
end

def production_hostname
  @production_hostname ||=
    ask_with_default("Production hostname?", :blue, "example.com")
end

def gemfile_entry(name, version = nil, require: true, force: false)
  @original_gemfile ||= IO.read("Gemfile")
  entry = @original_gemfile[/^\s*gem #{Regexp.quote(name.inspect)}.*$/]
  return if entry.nil? && !force

  require = (entry && entry[/\brequire:\s*([\S]+)/, 1]) || require
  version = (entry && entry[/, "([^"]+)"/, 1]) || version
  args = [name.inspect, version&.inspect, ("require: false" if require != true)].compact
  "gem #{args.join(', ')}\n"
end

def ask_with_default(question, color, default)
  return default unless $stdin.tty?

  question = (question.split("?") << " [#{default}]?").join
  answer = ask(question, color)
  answer.to_s.strip.empty? ? default : answer
end

def git_repo_specified?
  git_repo_url != "skip" && !git_repo_url.strip.empty?
end

def preexisting_git_repo?
  @preexisting_git_repo ||= (File.exist?(".git") || :nope)
  @preexisting_git_repo == true
end

def changes_to_commit?
  # Run git status and capture the output
  status_output = `git status --porcelain`

  # Check if the output is empty (no changes) or not (changes present)
  !status_output.empty?
end

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
  return if success

  puts "Command failed, exiting: #{cmd}"
  exit(1)
end

def run_rubocop_autocorrections
  run_with_clean_bundler_env "rubocop -A --fail-level A > /dev/null || true"
  run_with_clean_bundler_env "erblint --lint-all -a > /dev/null || true"
end

def create_database_and_initial_migration
  return if Dir["db/migrate/**/*.rb"].any?

  run_with_clean_bundler_env "bin/rails db:create"
  run_with_clean_bundler_env "bin/rails generate migration initial_migration"
end

def rewrite_json(file)
  json = JSON.parse(File.read(file))
  yield(json)
  File.write(file, JSON.pretty_generate(json) + "\n")
end

def git_commit(message)
  if !changes_to_commit?
    say "No changes to commit for #{message}", :yellow
    return
  end

  git add: "-A ."
  git commit: "-n -m '#{message}'"
end

def copy_dir(source, dest)
  source_dir = Pathname.new(__dir__).join(source).expand_path
  destination_root = Pathname.new(dest).expand_path

  if !source_dir.directory?
    say "Source directory does not exist or is not a directory", :red
    return
  end

  # Ensure the destination directory exists
  FileUtils.mkdir_p(destination_root)

  # Iterate over each file and directory in the source directory
  source_dir.glob("**/*").each do |file|
    if file.directory?
      # Ensure that the corresponding directory exists in the destination
      FileUtils.mkdir_p(destination_root.join(file.relative_path_from(source_dir)))
    else
      # Copy the file to the destination directory
      file_destination = destination_root.join(file.relative_path_from(source_dir))
      FileUtils.cp(file, file_destination)
      say "Copied #{file} to #{file_destination}", :green
    end
  end
end

apply_template!
