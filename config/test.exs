import Config

# Disable ALTAR backend auto-start for testing
# Tests will start it manually with their own registry
config :nsai_work,
  enable_altar: false,
  altar_registry: NsaiWork.Test.AltarRegistry

# Suppress logs during tests
config :logger, level: :warning
