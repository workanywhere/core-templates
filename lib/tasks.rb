require "fileutils"
require "pathname"

# Main method to process the tasks
def process_tasks
  @tasks_dir = Pathname.new(__dir__).join("tasks")
  destination_root = Pathname.new("lib/tasks")

  @tasks_dir.glob("**/*").each do |file|
    process_file(file, destination_root) if file.file?
  end
end

# Method to copy a file to the destination and commit the change
def process_file(file, destination_root)
  file_destination = destination_root.join(file.relative_path_from(@tasks_dir))
  FileUtils.mkdir_p(file_destination.dirname)
  FileUtils.cp(file, file_destination)

  git_commit("Add tasks #{file_destination}")
end

# Run the main method
process_tasks
