# frozen_string_literal: true

Rails.application.config.after_initialize do
  if defined?(Rails::Generators) # Avoid loading in production, or by `rails server` use defined?(Rails::Console) for CLI only.
    module ExtendScaffoldGenerator
      extend ActiveSupport::Concern

      # Doing so hook for are bypassed like hook_for :template_engine, etc...
      # def invoke_all
      #   super # This runs the default scaffold generation
      #   invoke_extra_generators
      # end

      # As they are Thor::Group, any method added should be executed.
      def invoke_extra_generators
        generate "rspec:system", name, *attributes
      end
    end

    # ScaffoldGenerator call ScaffoldControllerGenerator through hook_for :scaffold_controller, required: true
    require "rails/generators/rails/scaffold_controller/scaffold_controller_generator"
    Rails::Generators::ScaffoldControllerGenerator.include ExtendScaffoldGenerator
  end
end
