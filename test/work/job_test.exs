defmodule Work.JobTest do
  use ExUnit.Case
  doctest Work.Job

  alias Work.{Job, Error, Resources, Constraints}

  describe "new/1" do
    test "creates a job with defaults" do
      job =
        Job.new(
          kind: :tool_call,
          tenant_id: "test",
          namespace: "default",
          payload: %{}
        )

      assert job.status == :pending
      assert job.priority == :batch
      assert job.attempt == 0
      assert %Resources{} = job.resources
      assert %Constraints{} = job.constraints
    end

    test "generates ID and trace_id automatically" do
      job1 = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      job2 = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})

      assert is_binary(job1.id)
      assert is_binary(job1.trace_id)
      assert job1.id != job2.id
    end

    test "accepts custom resources" do
      job =
        Job.new(
          kind: :training_step,
          tenant_id: "test",
          namespace: "default",
          payload: %{},
          resources: Resources.new(cpu: 4.0, memory_mb: 8192, gpu: "A100")
        )

      assert job.resources.cpu == 4.0
      assert job.resources.gpu == "A100"
    end
  end

  describe "mark_queued/1" do
    test "updates status and queued_at" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      queued = Job.mark_queued(job)

      assert queued.status == :queued
      assert %DateTime{} = queued.queued_at
    end
  end

  describe "mark_running/3" do
    test "updates status with backend and worker info" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      running = Job.mark_running(job, :local, "worker-1")

      assert running.status == :running
      assert running.backend == :local
      assert running.worker_id == "worker-1"
      assert %DateTime{} = running.started_at
    end
  end

  describe "mark_succeeded/2" do
    test "updates status with result" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      succeeded = Job.mark_succeeded(job, %{answer: 42})

      assert succeeded.status == :succeeded
      assert succeeded.result == %{answer: 42}
      assert %DateTime{} = succeeded.completed_at
    end
  end

  describe "mark_failed/2" do
    test "updates status with error" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})

      error =
        Error.new(
          category: :timeout,
          code: "TIMEOUT",
          message: "Job timed out"
        )

      failed = Job.mark_failed(job, error)

      assert failed.status == :failed
      assert %Error{} = failed.error
      assert failed.error.code == "TIMEOUT"
    end
  end

  describe "increment_attempt/1" do
    test "increments attempt counter and resets status" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      job = %{job | status: :failed, attempt: 1}

      retried = Job.increment_attempt(job)

      assert retried.attempt == 2
      assert retried.status == :pending
    end
  end

  describe "terminal?/1" do
    test "returns true for terminal states" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})

      assert Job.terminal?(Job.mark_succeeded(job, nil))

      assert Job.terminal?(
               Job.mark_failed(job, Error.new(category: :internal, code: "ERR", message: "error"))
             )

      assert Job.terminal?(Job.mark_canceled(job))
    end

    test "returns false for non-terminal states" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})

      refute Job.terminal?(job)
      refute Job.terminal?(Job.mark_queued(job))
      refute Job.terminal?(Job.mark_running(job, :local, "w1"))
    end
  end

  describe "duration_ms/1" do
    test "returns nil if job not completed" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      assert Job.duration_ms(job) == nil

      running = Job.mark_running(job, :local, "w1")
      assert Job.duration_ms(running) == nil
    end

    test "returns duration in milliseconds when completed" do
      job = Job.new(kind: :tool_call, tenant_id: "test", namespace: "default", payload: %{})
      running = Job.mark_running(job, :local, "w1")

      Process.sleep(10)
      completed = Job.mark_succeeded(running, nil)

      duration = Job.duration_ms(completed)
      assert is_integer(duration)
      assert duration >= 10
    end
  end
end
