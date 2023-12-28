uncomment_lines "config/environments/production.rb", /config\.force_ssl = true/
uncomment_lines "config/environments/production.rb", /config\.active_job/
uncomment_lines "config/environments/production.rb", /raise_delivery_errors =/

comment_lines "config/environments/production.rb", /config\.active_job\.queue_adapter =/
comment_lines "config/environments/production.rb", /config\.active_job\.queue_name_prefix =/

gsub_file "config/environments/production.rb", /raise_delivery_errors = false/, "raise_delivery_errors = true"
gsub_file "config/environments/production.rb", /\bSTDOUT\b/, "$stdout"
gsub_file "config/environments/production.rb",
          "config.force_ssl = true",
          'config.force_ssl = ENV["RAILS_DISABLE_SSL"].blank?'
