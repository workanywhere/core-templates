require "bundler"
require "json"

RAILS_REQUIREMENT = "~> 7.1.2".freeze

# rails _7.1.2_ new --name my-test-app-2 --database=sqlite3 --template ~/WorkSpace/Rails/Rails7/RailsTemplates/core-templates/template.rb

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path
  assert_valid_options

  self.options = options.reverse_merge(
    css: "tailwind",
    javascript: "importmap",
    skip_jbuilder: true,
    skip_system_test: true,
    skip_test: true,
    skip_test_unit: true
  )

  template "Gemfile.tt", force: true

  template "example.env.tt"
  copy_file "editorconfig", ".editorconfig"
  copy_file "erb-lint.yml", ".erb-lint.yml"
  copy_file "overcommit.yml", ".overcommit.yml"
  template "ruby-version.tt", ".ruby-version", force: true

  run("gem install overcommit")

  copy_file "Thorfile"
  copy_file "Procfile"

  apply "Rakefile.rb"
  apply "bin/template.rb"
  apply "github/template.rb"
  apply "config/template.rb"
  apply "lib/template.rb"

  empty_directory_with_keep_file "app/lib"

  git :init unless preexisting_git_repo?
  empty_directory ".git/safe"

  after_bundle do
    append_to_file ".gitignore", <<~IGNORE

      # Ignore application config.
      /.env.development
      /.env.*local

      # Ignore locally-installed gems.
      /vendor/bundle/
    IGNORE

    create_database_and_initial_migration
    run_with_clean_bundler_env "bin/setup"

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

    copy_file "rubocop.yml", ".rubocop.yml"
    run_rubocop_autocorrections

    unless any_local_git_commits?
      git checkout: "-b main"
      git add: "-A ."
      git commit: "-n -m 'Set up project'"
      if git_repo_specified?
        git remote: "add origin #{git_repo_url.shellescape}"
        git push: "-u origin --all"
      end
    end
  end
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
    skip_gemfile: false,
    skip_bundle: false,
    skip_git: false,
    edge: false
  }
  valid_options.each do |key, expected|
    next unless options.key?(key)

    actual = options[key]
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

def any_local_git_commits?
  system("git log > /dev/null 2>&1")
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

apply_template!
