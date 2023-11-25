require "bundler"
require "json"

RAILS_REQUIREMENT = "~> 7.1.2".freeze

# rails _7.1.2_ new my-app-1 --database=sqlite3 --css=tailwind --javascript=importmap --skip-jbuilder --skip-test --template ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb
# rails _7.1.2_ new my-app-1 -m ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  self.options = options.reverse_merge(
    css: "tailwind",
    javascript: "importmap",
    skip_jbuilder: true,
    skip_system_test: true,
    skip_test: true,
    skip_test_unit: true
  )

  assert_valid_options

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

  copy_file "overcommit.yml", ".overcommit.yml"
  git_commit "Add .overcommit.yml"

  template "ruby-version.tt", ".ruby-version", force: true
  git_commit "Add .ruby-version"

  run("gem install overcommit")

  copy_file "Thorfile"
  git_commit "Add Thorfile"
  copy_file "Procfile"
  git_commit "Add Procfile"

  apply "Rakefile.rb"
  git_commit "Add Rakefile"
  apply "bin/template.rb"
  git_commit "Add bin"
  apply "github/template.rb"
  git_commit "Add GitHub templates"
  apply "config/template.rb"
  git_commit "Add config"
  apply "lib/template.rb"
  git_commit "Add lib"
  apply "lib/templates.rb"
  git_commit "Add templates"

  empty_directory_with_keep_file "app/lib"

  empty_directory ".git/safe"

  after_bundle do
    git_commit "Initial setup"
    run("rails generate rspec:install")
    git_commit "Add RSpec"
    run_rubocop_autocorrections
    git_commit "Run rubocop autocorrections"
  end

  run("bundle install")
  git_commit "Run bundle install"

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

  %w[
    bundler-audit
    erb_lint
    rubocop
    rubocop-performance
    rubocop-rake
    rubocop-rspec
    rubocop-gitlab-security
    rubocop-capybara
    rubocop-factory_bot
  ].each do |tool|
    run("gem install #{tool}")
  end

  binstubs = %w[bundler bundler-audit erb_lint rubocop thor]
  run_with_clean_bundler_env "bundle binstubs #{binstubs.join(' ')} --force"
  git_commit "Install binstubs"

  copy_file "rubocop.yml", ".rubocop.yml"
  git_commit "Add .rubocop.yml"

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
    "asset_pipeline" => "sprockets",
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
  run_with_clean_bundler_env "bin/rubocop -A --fail-level A > /dev/null || true"
  run_with_clean_bundler_env "bin/erblint --lint-all -a > /dev/null || true"
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
  return unless changes_to_commit?

  git add: "-A ."
  git commit: "-n -m '#{message}'"
end

apply_template!
