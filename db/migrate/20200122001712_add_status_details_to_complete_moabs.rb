class AddStatusDetailsToCompleteMoabs < ActiveRecord::Migration[5.1]
  def change
    add_column :complete_moabs, :status_details, :string
  end
end
