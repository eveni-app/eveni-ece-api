source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# ── Autenticación y Autorización (NOM-024 RBAC) ─────────────────────────────
gem "devise"
gem "devise-jwt"
gem "pundit"

# ── Borrado lógico / Legal Hold (LFPDPPP + NOM-004 retención 5 años) ────────
gem "discard"

# ── Auditoría e inmutabilidad a nivel de base de datos (NOM-024) ─────────────
gem "logidze"

# ── Serialización JSON y HL7 FHIR ────────────────────────────────────────────
gem "blueprinter"

# ── CORS para interacción con el frontend SPA ────────────────────────────────
gem "rack-cors"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  # ── Suite de Pruebas (NOM-004/NOM-024 Compliance Testing) ──────────────────
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
end

group :test do
  gem "webmock"
end
