class CreateLlmsRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :llms_runs, id: :uuid do |t|
      t.text :content, null: false
      t.datetime :expires_at, null: false
      t.datetime :paid_at

      t.timestamps
    end

    add_index :llms_runs, :expires_at
  end
end
