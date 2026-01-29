defmodule NsaiWork.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/North-Shore-AI/nsai_work"

  def project do
    [
      app: :nsai_work,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      name: "NsaiWork",
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
      mod: {NsaiWork.Application, []}
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
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:supertester, "~> 0.5.1", only: :test}
    ]
  end

  defp description do
    """
    NsaiWork - Unified job scheduler for the North-Shore-AI platform.
    Protocol-first, multi-tenant job scheduling with priority queues,
    resource-aware scheduling, and pluggable backend execution.
    """
  end

  defp package do
    [
      name: "nsai_work",
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
      assets: %{"assets" => "assets"},
      logo: "assets/work.svg",
      extras: [
        {"README.md", title: "Overview"},
        {"guides/getting-started.md", title: "Getting Started"},
        {"guides/custom-backends.md", title: "Custom Backends"},
        {"guides/telemetry.md", title: "Telemetry"},
        {"examples/README.md", filename: "examples", title: "Examples"},
        {"CHANGELOG.md", title: "Changelog"},
        {"LICENSE", title: "License"}
      ],
      groups_for_extras: [
        Guides: [
          "guides/getting-started.md",
          "guides/custom-backends.md",
          "guides/telemetry.md"
        ],
        Examples: ["examples/README.md"],
        Reference: ["CHANGELOG.md", "LICENSE"]
      ],
      groups_for_modules: [
        "Core IR": [
          NsaiWork.Job,
          NsaiWork.Resources,
          NsaiWork.Constraints,
          NsaiWork.Error
        ],
        Scheduling: [
          NsaiWork.Queue,
          NsaiWork.Scheduler,
          NsaiWork.Executor
        ],
        Backends: [
          NsaiWork.Backend,
          NsaiWork.Backends.Local,
          NsaiWork.Backends.Altar,
          NsaiWork.Backends.Mock
        ],
        "ALTAR Integration": [
          NsaiWork.AltarTools
        ],
        Infrastructure: [
          NsaiWork.Registry,
          NsaiWork.Telemetry,
          NsaiWork.Supervisor
        ]
      ]
    ]
  end
end
