require "fileutils"
require "pathname"

# Main method to process the templates
def process_templates
  @templates_dir = Pathname.new(__dir__).join("support")
  destination_root = Pathname.new("spec/support")

  @templates_dir.glob("**/*").each do |file|
    process_file(file, destination_root) if file.file?
  end
end

# Method to copy a file to the destination and commit the change
def process_file(file, destination_root)
  file_destination = destination_root.join(file.relative_path_from(@templates_dir))
  FileUtils.mkdir_p(file_destination.dirname)
  FileUtils.cp(file, file_destination)
  git_commit("Add spec support #{file_destination}")
end

# Run the main method
process_templates

insert_into_file "spec/rails_helper.rb", "config.filter_rails_from_backtrace!", <<-RUBY, after: "end"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
RUBY
