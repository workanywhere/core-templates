desc "Run erblint"
task erblint: :environment do
  sh "bin/erblint --lint-all"
end

namespace :erblint do
  desc "Autocorrect erblint offenses"
  task autocorrect: :environment do
    sh "bin/erblint --lint-all -a"
  end
end
