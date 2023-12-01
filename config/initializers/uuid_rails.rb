# frozen_string_literal: true

require "rails/railtie"
require "active_record"

module UuidArExt
  extend ActiveSupport::Concern

  included do
    attribute :id, UuidV7::Type.new

    after_initialize :pre_set_id # Get immediate UUID value on new record. It does not compromise record.persisted? or record.new_record?
  end

  private

  def pre_set_id
    self.id ||= SecureRandom.uuid_v7
  end
end

ActiveSupport.on_load(:active_record) do
  include UuidArExt unless include?(UuidArExt)
end
