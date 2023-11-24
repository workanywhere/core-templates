Rails.application.config.generators do |generator|
  # Disable generators we don't need.
  generator.javascripts false
  generator.stylesheets false
  generator.orm :active_record, primary_key_type: :uuid
end
