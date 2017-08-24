class CreatePreservationCopies < ActiveRecord::Migration[5.1]
  def change
    create_table :preservation_copies do |t|
      t.integer :current_version, null: false
      t.string :status
      t.bigint :last_audited, index: true  # this is intended to store seconds after the unix epoch, for efficient date comparisons
      t.references :preserved_object, index: true, foreign_key: true, null: false
      t.references :endpoint, index: true, foreign_key: true, null: false

      t.timestamps
    end

  end
end
