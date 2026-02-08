class AddDetailsToInstitutes < ActiveRecord::Migration[8.0]
  def change
    add_column :institutes, :registered_poc, :string
    add_column :institutes, :service_started_on, :date
    add_column :institutes, :owner_name, :string
    add_column :institutes, :age_of_service, :integer
    add_column :institutes, :billing_type, :string
    add_column :institutes, :expiry_date, :date
    add_column :institutes, :other_details, :text
  end
end
