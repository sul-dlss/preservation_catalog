class IndexSomeMoreCols < ActiveRecord::Migration[5.1]
  def change
    add_index :endpoint_types, :type_name, :unique => true
    add_index :endpoint_types, :endpoint_class
  end
end
