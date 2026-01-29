defmodule NsaiWorkTest do
  use ExUnit.Case, async: true

  alias NsaiWork.Backends.Mock
  alias NsaiWork.{Job, Registry}

  setup do
    # Reset mock backend between tests
    Mock.reset()

    # Use unique tenant IDs to avoid conflicts in async tests
    tenant_id = "test_#{System.unique_integer([:positive])}"

    {:ok, tenant_id: tenant_id}
  end

  describe "submit/1" do
    test "submits a job and executes it", %{tenant_id: tenant_id} do
      # Set up telemetry handler to wait for job completion
      test_pid = self()
      ref = make_ref()
      handler_id = "test-handler-#{inspect(ref)}"

      :telemetry.attach(
        handler_id,
        [:nsai_work, :job, :completed],
        fn _event, _measurements, metadata, config ->
          send(config.test_pid, {:job_completed, metadata.job_id})
        end,
        %{test_pid: test_pid}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      job =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "default",
          payload: %{tool: "echo", args: ["hello"]}
        )

      {:ok, submitted} = NsaiWork.submit(job)
      assert submitted.status == :queued

      # Wait for job completion via telemetry (deterministic, no polling)
      job_id = submitted.id
      assert_receive {:job_completed, ^job_id}, 1000

      # Verify final state
      {:ok, executed} = NsaiWork.get(submitted.id)
      assert executed.status in [:running, :succeeded]
    end

    test "submits and tracks job", %{tenant_id: tenant_id} do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "default",
          payload: %{}
        )

      {:ok, submitted} = NsaiWork.submit(job)

      # Job should be queued
      assert submitted.status == :queued

      # Should be retrievable
      {:ok, retrieved} = NsaiWork.get(submitted.id)
      assert retrieved.id == submitted.id
    end
  end

  describe "get/1" do
    test "retrieves a job by ID", %{tenant_id: tenant_id} do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "default",
          payload: %{}
        )

      Registry.put(job)

      {:ok, retrieved} = NsaiWork.get(job.id)
      assert retrieved.id == job.id
    end

    test "returns error for nonexistent job" do
      assert {:error, :not_found} = NsaiWork.get("nonexistent_#{System.unique_integer()}")
    end
  end

  describe "list/2" do
    test "lists jobs for a tenant", %{tenant_id: tenant_id} do
      job1 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "default",
          payload: %{}
        )

      job2 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "production",
          payload: %{}
        )

      # Use unique tenant for other job to ensure isolation
      other_tenant = "other_#{System.unique_integer([:positive])}"

      job3 =
        Job.new(
          kind: :tool_call,
          tenant_id: other_tenant,
          namespace: "default",
          payload: %{}
        )

      Registry.put(job1)
      Registry.put(job2)
      Registry.put(job3)

      jobs = NsaiWork.list(tenant_id)
      assert length(jobs) == 2
      assert Enum.all?(jobs, &(&1.tenant_id == tenant_id))
    end

    test "filters jobs by namespace", %{tenant_id: tenant_id} do
      job1 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "default",
          payload: %{}
        )

      job2 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant_id,
          namespace: "production",
          payload: %{}
        )

      Registry.put(job1)
      Registry.put(job2)

      jobs = NsaiWork.list(tenant_id, namespace: "production")
      assert length(jobs) == 1
      assert hd(jobs).namespace == "production"
    end
  end

  describe "stats/0" do
    test "returns scheduler and registry statistics" do
      stats = NsaiWork.stats()

      assert Map.has_key?(stats, :scheduler)
      assert Map.has_key?(stats, :registry)
      assert Map.has_key?(stats.scheduler, :queues)
      assert Map.has_key?(stats.registry, :total)
    end
  end
end
