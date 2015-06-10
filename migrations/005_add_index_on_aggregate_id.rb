Sequel.migration do
  up do
    alter_table(:events) do
      add_index :aggregate_id
    end
  end

  down do
    alter_table(:events) do
      drop_index :aggregate_id
    end
  end
end
