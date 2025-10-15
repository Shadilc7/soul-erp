class AddEligibleCriteriaToCertificateConfigurations < ActiveRecord::Migration[8.0]
  def change
    add_column :certificate_configurations, :eligible_criteria, :decimal, precision: 5, scale: 2
  end
end
