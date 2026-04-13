class AddAddressFieldsToParticipants < ActiveRecord::Migration[8.0]
  def change
    add_column :participants, :address_line1, :string
    add_column :participants, :address_line2, :string
    add_column :participants, :place, :string
  end
end
