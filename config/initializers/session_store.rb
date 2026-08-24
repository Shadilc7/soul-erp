# Configure cookie-based session store with persistent expiry to prevent auto-logout
Rails.application.config.session_store :cookie_store,
  key: "_soul_erp_session",
  expire_after: 30.days,
  same_site: :lax,
  secure: Rails.env.production?
