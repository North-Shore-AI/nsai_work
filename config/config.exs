import Config

# Configure NSAI.Work application settings

# ALTAR Backend Configuration
# Enable ALTAR backend integration (set to true to use ALTAR tools)
config :nsai_work,
  enable_altar: false,
  altar_registry: NsaiWork.AltarRegistry

# Import environment-specific configuration
# These files are created when you run `mix new` with the --sup flag
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
