class CreateNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :notes do |t|
      t.string :title, null: false
      t.integer :status, default: 0, null: false
      t.boolean :archived, default: false, null: false
      t.text :metadata
      t.timestamps
    end
    add_index :notes, :title, unique: true
  end
end
