class RegistrationSetting < ApplicationRecord
  serialize :enabled_institutes, coder: YAML  # Specify YAML as the coder

  before_validation :normalize_enabled_institutes

  def self.instance
    first_or_create!(enabled_institutes: Institute.active.pluck(:id))
  rescue StandardError
    # Keep the app usable even if singleton creation fails in edge environments.
    first || new(enabled_institutes: [])
  end

  # Helper method to ensure we always work with integers
  def enabled_institute_ids
    (enabled_institutes || []).map(&:to_i)
  end

  private

  def normalize_enabled_institutes
    self.enabled_institutes = Array(enabled_institutes).reject(&:blank?).map(&:to_i).uniq
  end
end
