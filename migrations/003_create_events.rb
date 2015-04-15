Sequel.migration do
  up do
    create_table(:events) do
      column :id, :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      column :body, :json, null: false
      column :aggregate_id, :uuid, null: false
      column :user_id, Integer
      column :type, String, null: false
      column :created_at, DateTime, null: false
    end
  end

  down do
    drop_table :gigs
  end
end
