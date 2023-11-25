Dir[File.join(File.dirname(__FILE__), "templates", "**", "*")].each do |file|
  if File.directory?(file)
    empty_directory file.split("lib/templates/").last

    next
  end

  file_destination = File.join("lib/templates", File.dirname(file).split("lib/templates/").last, File.basename(file))
  copy_file file, file_destination
  git_commit "Add template #{file_destination}"
end
