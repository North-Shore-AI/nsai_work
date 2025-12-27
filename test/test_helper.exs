ExUnit.start()

# Configure ExUnit for async tests
ExUnit.configure(assert_receive_timeout: 1000)
