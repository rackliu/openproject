class AddViews < ActiveRecord::Migration[6.1]
  def change
    create_table :views do |t|
      t.references :query, null: false, foreign_key: true, index: true
      t.jsonb :options, default: {}
      t.string :type

      t.timestamps
    end
  end
end
