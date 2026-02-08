# frozen_string_literal: true

Kaminari.configure do |config|
  # Default number of items per page
  config.default_per_page = 10

  # Maximum number of pages shown in pagination
  config.max_pages = 5

  # Default options for link_to_next_page
  config.page_method_name = :page
  # config.max_per_page = nil
  # config.window = 4
  # config.outer_window = 0
  # config.left = 0
  # config.right = 0
  # config.param_name = :page
  # config.params_on_first_page = false
end
