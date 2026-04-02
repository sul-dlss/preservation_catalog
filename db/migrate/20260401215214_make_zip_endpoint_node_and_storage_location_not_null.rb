# frozen_string_literal: true

class MakeZipEndpointNodeAndStorageLocationNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :zip_endpoints, :endpoint_node, false
    change_column_null :zip_endpoints, :storage_location, false
  end
end
