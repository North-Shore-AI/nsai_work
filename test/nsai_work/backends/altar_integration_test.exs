defmodule NsaiWork.Backends.AltarIntegrationTest do
  use ExUnit.Case

  alias NsaiWork.Backends.Altar, as: AltarBackend
  alias NsaiWork.{Error, Job}

  @moduletag :integration

  # This test demonstrates ALTAR integration but requires manual setup
  # To run: Start iex with the project and manually register tools

  @tag :skip
  test "ALTAR integration example" do
    # This is a documentation test showing how to use ALTAR
    # See README.md for full setup instructions
    :ok
  end

  describe "supports?/1" do
    test "supports tool_call jobs" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      assert AltarBackend.supports?(job) == true
    end

    test "does not support other job types" do
      for kind <- [
            :experiment_step,
            :workflow_step,
            :training_step,
            :inference,
            :backend_command,
            :composite
          ] do
        job = Job.new(kind: kind, tenant_id: "test", namespace: "default", payload: %{})
        assert AltarBackend.supports?(job) == false
      end
    end
  end

  describe "error handling" do
    test "returns error for unsupported job kind" do
      job = Job.new(kind: :experiment_step, tenant_id: "test", namespace: "default", payload: %{})

      assert {:error, %Error{} = error} = AltarBackend.execute(job)
      assert error.code == "UNSUPPORTED_JOB_KIND"
      assert error.retryable == false
    end

    test "cancel returns not implemented" do
      assert {:error, %Error{} = error} = AltarBackend.cancel("some-job-id")
      assert error.code == "NOT_IMPLEMENTED"
    end

    test "status returns not implemented" do
      assert {:error, %Error{} = error} = AltarBackend.status("some-job-id")
      assert error.code == "NOT_IMPLEMENTED"
    end
  end
end
