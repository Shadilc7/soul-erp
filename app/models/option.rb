class Option < ApplicationRecord
  belongs_to :question, counter_cache: true

  validates :text, presence: true

  # For backward compatibility with existing code that uses 'value'
  alias_attribute :value, :text

  # Ensure value is always synced with text
  before_save :sync_value_with_text

  scope :ordered, -> { order(:created_at) }

  def to_s
    text.to_s
  end

  private

  def sync_value_with_text
    # Ensure value is always the same as text for backward compatibility
    self.value = text if value.blank? || value != text
  end
end
