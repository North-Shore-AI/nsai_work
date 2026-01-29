defmodule NsaiWork.AltarTools do
  @moduledoc """
  Tool registration for ALTAR integration.

  Provides helpers to register Work-compatible tools with ALTAR's LATER runtime.

  ## Overview

  ALTAR provides a local execution runtime (LATER) that can execute registered tools.
  This module simplifies the registration process for tools that will be invoked
  via Work's ALTAR backend.

  ## Usage

      # Register a simple tool
      NsaiWork.AltarTools.register(
        "calculator_add",
        "Add two numbers",
        %{
          type: :OBJECT,
          properties: %{
            "a" => %{type: :NUMBER},
            "b" => %{type: :NUMBER}
          },
          required: ["a", "b"]
        },
        fn args ->
          {:ok, args["a"] + args["b"]}
        end
      )

      # Register a tool with custom validation
      NsaiWork.AltarTools.register(
        "proposer_extract",
        "Extract claims from document",
        %{
          type: :OBJECT,
          properties: %{
            "doc_id" => %{type: :STRING, description: "Document identifier"},
            "max_claims" => %{type: :NUMBER, description: "Maximum claims to extract"}
          },
          required: ["doc_id"]
        },
        &MyApp.CNS.Proposer.extract/1
      )

  ## Tool Function Requirements

  Tool functions must:
  - Accept a single argument (map of parameters)
  - Return `{:ok, result}` on success
  - Return `{:error, reason}` on failure

  ## Configuration

  The ALTAR registry name can be configured:

      config :nsai_work,
        altar_registry: NsaiWork.AltarRegistry
  """

  alias Altar.ADM.FunctionDeclaration
  alias Altar.LATER.Registry

  @doc """
  Register a tool with ALTAR.

  ## Parameters

    * `name` - Tool name (must be unique within the registry)
    * `description` - Human-readable description of the tool
    * `parameters` - Parameter schema in ADM format
    * `fun` - Function to execute (arity 1)

  ## Parameter Schema Format

  The parameter schema follows ALTAR's ADM type system:

      %{
        type: :OBJECT,
        properties: %{
          "param_name" => %{
            type: :STRING | :NUMBER | :BOOLEAN | :ARRAY | :OBJECT,
            description: "Parameter description",
            enum: ["option1", "option2"],  # optional
            items: %{...}                  # for ARRAY types
          }
        },
        required: ["param_name"]  # optional list of required params
      }

  ## Examples

      # Simple string transformation tool
      NsaiWork.AltarTools.register(
        "uppercase",
        "Convert text to uppercase",
        %{
          type: :OBJECT,
          properties: %{"text" => %{type: :STRING}},
          required: ["text"]
        },
        fn %{"text" => text} -> {:ok, String.upcase(text)} end
      )

      # Tool with multiple parameters
      NsaiWork.AltarTools.register(
        "search_documents",
        "Search document corpus",
        %{
          type: :OBJECT,
          properties: %{
            "query" => %{type: :STRING, description: "Search query"},
            "limit" => %{type: :NUMBER, description: "Max results"},
            "filters" => %{
              type: :OBJECT,
              properties: %{
                "category" => %{type: :STRING}
              }
            }
          },
          required: ["query"]
        },
        &MyApp.Search.search/1
      )

  ## Returns

    * `:ok` on successful registration
    * `{:error, reason}` if registration fails
  """
  @spec register(String.t(), String.t(), map(), function()) :: :ok | {:error, term()}
  def register(name, description, parameters, fun) when is_function(fun, 1) do
    case FunctionDeclaration.new(%{
           name: name,
           description: description,
           parameters: parameters
         }) do
      {:ok, decl} ->
        Registry.register_tool(registry_name(), decl, fun)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if a tool is registered.

  ## Parameters

    * `name` - Tool name

  ## Examples

      if NsaiWork.AltarTools.registered?("calculator_add") do
        IO.puts("Tool is available")
      end
  """
  @spec registered?(String.t()) :: boolean()
  def registered?(name) do
    case Registry.lookup_tool(registry_name(), name) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  # Private helpers

  defp registry_name do
    Application.get_env(:nsai_work, :altar_registry, NsaiWork.AltarRegistry)
  end
end
