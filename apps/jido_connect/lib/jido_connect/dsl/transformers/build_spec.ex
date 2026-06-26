defmodule Jido.Connect.Dsl.Transformers.BuildSpec do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias Jido.Connect.Catalog.Builder
  alias Jido.Connect.Dsl.OperationRules
  alias Jido.Connect.Dsl.SpecBuilder
  alias Jido.Connect.Jido.{ModuleGenerator, ProjectionBuilder}
  alias Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    with :ok <- validate_operation_rules(dsl_state),
         {:ok, spec} <- SpecBuilder.build(dsl_state, Transformer) do
      integration_module = Transformer.get_persisted(dsl_state, :module)
      projection = ProjectionBuilder.build(integration_module, spec)

      manifest =
        Builder.manifest_from_spec(spec, integration_module, projection,
          version: project_version(spec.package)
        )

      generated_modules = ModuleGenerator.generated_modules_ast(projection)

      dsl_state =
        dsl_state
        |> Transformer.persist(:jido_connect_spec, spec)
        |> Transformer.persist(:jido_projection, projection)
        |> Transformer.eval(
          [],
          quote do
            @behaviour Jido.Connect.Provider

            @impl Jido.Connect.Provider
            def integration, do: unquote(Macro.escape(spec))

            def jido_action_modules,
              do: unquote(Macro.escape(Enum.map(projection.actions, & &1.module)))

            def jido_sensor_modules,
              do: unquote(Macro.escape(Enum.map(projection.sensors, & &1.module)))

            def jido_plugin_module, do: unquote(projection.module)

            @impl Jido.Connect.Provider
            def jido_connect_manifest, do: unquote(Macro.escape(manifest))

            @impl Jido.Connect.Provider
            def jido_connect_modules do
              %{
                actions: jido_action_modules(),
                sensors: jido_sensor_modules(),
                plugin: jido_plugin_module()
              }
            end

            def jido_projection, do: unquote(Macro.escape(projection))

            unquote_splicing(generated_modules)
          end
        )

      {:ok, dsl_state}
    end
  end

  defp validate_operation_rules(dsl_state) do
    case OperationRules.violations(dsl_state, Transformer) do
      [] -> :ok
      [violation | _] -> {:error, OperationRules.dsl_error(violation)}
    end
  end

  defp project_version(package) do
    if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :config, 0) do
      config = Mix.Project.config()

      if Keyword.get(config, :app) == package do
        Keyword.get(config, :version)
      end
    end
  rescue
    _error -> nil
  end
end
