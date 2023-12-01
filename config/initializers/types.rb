# require "uuid_v7"
require_relative "../../app/types/uuid_v7"

ActiveModel::Type.register(:uuid, UuidV7::Type)