# frozen_string_literal: true

Rails.application.config.after_initialize do
  if defined?(Rails::Generators) # Avoid loading in production, or by `rails server` use defined?(Rails::Console) for CLI only.
    module ExtendScaffoldGenerator
      extend ActiveSupport::Concern

      def invoke_all
        super # This runs the default scaffold generation
        invoke_extra_generators
      end

      def invoke_extra_generators
        generate "rspec:system", name, *attributes
      end
    end

    require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"
    Rails::Generators::ScaffoldControllerGenerator.include ExtendScaffoldGenerator
  end
end
