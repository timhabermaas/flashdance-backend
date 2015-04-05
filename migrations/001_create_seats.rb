Sequel.migration do
  up do
    create_table(:rows) do
      primary_key :id
      Integer :number, null: false
      Integer :y, null: false
    end

    create_table(:seats) do
      primary_key :id
      Integer :row_id, null: false
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
