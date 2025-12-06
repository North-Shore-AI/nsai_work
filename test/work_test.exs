defmodule WorkTest do
  use ExUnit.Case
  doctest Work

  alias Work.{Job, Registry}

  setup do
    # Reset mock backend between tests
    Work.Backends.Mock.reset()
    :ok
  end

  describe "submit/1" do
    test "submits a job and executes it" do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: "test",
          namespace: "default",
          payload: %{tool: "echo", args: ["hello"]}
        )

      {:ok, submitted} = Work.submit(job)
      assert submitted.status == :queued

      # Wait for execution
      Process.sleep(200)

      # Check job status
      {:ok, executed} = Work.get(submitted.id)
      assert executed.status in [:running, :succeeded]
    end

    test "submits and tracks job" do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: "test2",
          namespace: "default",
          payload: %{}
        )

      {:ok, submitted} = Work.submit(job)

      # Job should be queued
      assert submitted.status == :queued

      # Should be retrievable
      {:ok, retrieved} = Work.get(submitted.id)
      assert retrieved.id == submitted.id
    end
  end

  describe "get/1" do
    test "retrieves a job by ID" do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: "test",
          namespace: "default",
          payload: %{}
        )

      Registry.put(job)

      {:ok, retrieved} = Work.get(job.id)
      assert retrieved.id == job.id
    end

    test "returns error for nonexistent job" do
      assert {:error, :not_found} = Work.get("nonexistent")
    end
  end

  describe "list/2" do
    test "lists jobs for a tenant" do
      # Use unique tenant to avoid conflicts with other tests
      tenant = "tenant_#{:rand.uniform(100_000)}"

      job1 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant,
          namespace: "default",
          payload: %{}
        )

      job2 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant,
          namespace: "production",
          payload: %{}
        )

      job3 =
        Job.new(
          kind: :tool_call,
          tenant_id: "other_tenant",
          namespace: "default",
          payload: %{}
        )

      Registry.put(job1)
      Registry.put(job2)
      Registry.put(job3)

      jobs = Work.list(tenant)
      assert length(jobs) == 2
      assert Enum.all?(jobs, &(&1.tenant_id == tenant))
    end

    test "filters jobs by namespace" do
      # Use unique tenant to avoid conflicts
      tenant = "tenant_#{:rand.uniform(100_000)}"

      job1 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant,
          namespace: "default",
          payload: %{}
        )

      job2 =
        Job.new(
          kind: :tool_call,
          tenant_id: tenant,
          namespace: "production",
          payload: %{}
        )

      Registry.put(job1)
      Registry.put(job2)

      jobs = Work.list(tenant, namespace: "production")
      assert length(jobs) == 1
      assert hd(jobs).namespace == "production"
    end
  end

  describe "stats/0" do
    test "returns scheduler and registry statistics" do
      stats = Work.stats()

      assert Map.has_key?(stats, :scheduler)
      assert Map.has_key?(stats, :registry)
      assert Map.has_key?(stats.scheduler, :queues)
      assert Map.has_key?(stats.registry, :total)
    end
  end
end
