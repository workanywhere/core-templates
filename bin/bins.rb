require "fileutils"
require "pathname"

# Main method to process the bins
def process_bins
  @bins_dir = Pathname.new(__dir__).join("bins")
  destination_root = Pathname.new("bin")

  @bins_dir.glob("**/*").each do |file|
    process_file(file, destination_root) if file.file?
  end
end

# Method to copy a file to the destination and commit the change
def process_file(file, destination_root)
  file_destination = destination_root.join(file.relative_path_from(@bins_dir))
  # FileUtils.mkdir_p(file_destination.dirname)
  # If the extension is .erb.tt, we need to process it
  if file.extname == ".erb.tt"
    # and remove the extension .erb.tt
    template file, file_destination.gsub(/\.erb\.tt$/, ""), force: true
  else
    # FileUtils.cp(file, file_destination)
    copy_file file, file_destination, force: true
  end
  chmod file_destination, "+x"

  git_commit("Add bins #{file_destination}")
end

# Run the main method
process_bins
