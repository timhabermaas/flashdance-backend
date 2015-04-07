Sequel.migration do
  up do
    run 'CREATE EXTENSION "uuid-ossp"'

    create_table(:rows) do
      column :id, :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      Integer :number, null: false
      Integer :y, null: false
    end

    create_table(:seats) do
      column :id, :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      column :row_id, :uuid, null: false
      Integer :number, null: false
      Integer :x, null: false
      Boolean :usable, null: false, default: true
    end
  end

  down do
    drop_table :seats
    drop_table :rows
  end
end
