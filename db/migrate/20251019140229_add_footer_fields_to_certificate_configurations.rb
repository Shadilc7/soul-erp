class AddFooterFieldsToCertificateConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_configurations, :certificate_left_footer, :string
    add_column :certificate_configurations, :certificate_right_footer, :string
  end
end
