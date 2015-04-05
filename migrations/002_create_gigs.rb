Sequel.migration do
  up do
    create_table(:gigs) do
      primary_key :id
      String :title, null: false
      DateTime :date, null: false
    end
  end

  down do
    drop_table :gigs
  end
end
