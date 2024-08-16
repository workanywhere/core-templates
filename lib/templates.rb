require "fileutils"
require "pathname"

# Main method to process the templates
def process_templates
  @templates_dir = Pathname.new(__dir__).join("templates")
  destination_root = Pathname.new("lib/templates")

  @templates_dir.glob("**/*").each do |file|
    process_file(file, destination_root) if file.file?
  end
end

# Method to copy a file to the destination and commit the change
def process_file(file, destination_root)
  if options[:database] == "postgresql"
    if file.to_s.include?("active_record/migration")
      return # Migration files are not needed for PostgreSQL as it supports UUID natively
    end
  end
  file_destination = destination_root.join(file.relative_path_from(@templates_dir))
  # FileUtils.mkdir_p(file_destination.dirname)
  # FileUtils.cp(file, file_destination)
  copy_file file, file_destination
  git_commit("Add template #{file_destination}")
end

# Run the main method
process_templates
