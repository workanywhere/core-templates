# Source: https://github.com/rspec/rspec-rails/blob/6-1-maintenance/lib/generators/rspec/model/templates/model_spec.rb
require 'rails_helper'

<% module_namespacing do -%>
RSpec.describe <%= class_name %>, <%= type_metatag(:model) %> do
  pending "add some examples to [!!!] (or delete) #{__FILE__}"
end
<% end -%>
