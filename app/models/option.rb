class Option < ApplicationRecord
  belongs_to :question

  # Add default value at the application level
  attribute :text, :string, default: -> { "Option #{Time.now.to_i}" }

  validates :text, presence: true

  # For backward compatibility with existing code that uses 'value'
  alias_attribute :value, :text

  # Ensure value is always synced with text
  before_save :sync_value_with_text
  after_initialize :set_default_text

  scope :ordered, -> { order(:created_at) }

  before_validation :ensure_text_present

  private

  def set_default_text
    # Set default text when object is initialized
    self.text ||= "Option #{Time.now.to_i}"
  end

  def ensure_text_present
    # Only set default text if it's blank and not marked for destruction
    if text.blank? && !marked_for_destruction?
      self.text = "Option #{Time.now.to_i}"
    end
  end

  def sync_value_with_text
    # Ensure value is always the same as text for backward compatibility
    self.value = text if value.blank? || value != text
  end
end
