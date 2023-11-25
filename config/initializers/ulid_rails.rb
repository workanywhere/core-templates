# frozen_string_literal: true

require "rails/railtie"
require "active_record"

module UildArExt
  extend ActiveSupport::Concern

  included do
    include ULID::Rails
    ulid :id # , auto_generate: true # Why waiting for before create callback?
    after_initialize :pre_set_id # Get immediate ULID on new record. It does not compromise record.persisted? or record.new_record?
  end

  private

  def pre_set_id
    self.id ||= ULID.generate
  end
end

ActiveSupport.on_load(:active_record) do
  include UildArExt unless include?(UildArExt)
end
