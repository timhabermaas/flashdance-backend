Sequel.migration do
  up do
    add_column :rows, :gig_id, :uuid, null: false
  end

  down do
    remove_column :rows, :gig_id
  end
end
