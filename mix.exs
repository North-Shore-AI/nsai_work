defmodule Work.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/North-Shore-AI/work"

  def project do
    [
      app: :work,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      name: "NSAI.Work",
      source_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Work.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core dependencies
      {:telemetry, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:altar, "~> 0.2.0"},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:supertester, "~> 0.4.0", only: :test}
    ]
  end

  defp description do
    """
    NSAI.Work - Unified job scheduler for the North-Shore-AI platform.
    Protocol-first, multi-tenant job scheduling with priority queues,
    resource-aware scheduling, and pluggable backend execution.
    """
  end

  defp package do
    [
      name: "work",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Core IR": [
          Work.Job,
          Work.Resources,
          Work.Constraints,
          Work.Error
        ],
        Scheduling: [
          Work.Queue,
          Work.Scheduler,
          Work.Executor
        ],
        Backends: [
          Work.Backend,
          Work.Backends.Local,
          Work.Backends.Altar,
          Work.Backends.Mock
        ],
        "ALTAR Integration": [
          Work.AltarTools
        ],
        Infrastructure: [
          Work.Registry,
          Work.Telemetry,
          Work.Supervisor
        ]
      ]
    ]
  end
end
