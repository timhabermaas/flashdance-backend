Sequel.migration do
  up do
    create_table(:gigs) do
      column :id, :uuid, default: Sequel.function(:uuid_generate_v4), primary_key: true
      String :title, null: false
      DateTime :date, null: false
    end
  end

  down do
    drop_table :gigs
  end
end
