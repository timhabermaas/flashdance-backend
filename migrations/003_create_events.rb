Sequel.migration do
  up do
    execute "CREATE SEQUENCE events_global_version_seq START 1;"

    create_table(:events) do
      column :id, :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      column :body, :json, null: false
      column :aggregate_id, :uuid, null: false
      column :user_id, Integer
      column :type, String, null: false
      column :global_version, Integer, null: false, default: Sequel.function(:nextval, 'events_global_version_seq')
      column :created_at, DateTime, null: false
    end
  end

  down do
    drop_table :events
  end
end
