defmodule Jido.Connect.Jido.ActionProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Action` module."

  alias Jido.Connect.Field

  @schema Zoi.struct(
            __MODULE__,
            %{
              module: Zoi.module(),
              integration_module: Zoi.module(),
              integration_id: Zoi.atom(),
              action_id: Zoi.string(),
              name: Zoi.string(),
              label: Zoi.string(),
              description: Zoi.string(),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              resource: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              verb: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              data_classification: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              input: Zoi.list(Field.schema()) |> Zoi.default([]),
              output: Zoi.list(Field.schema()) |> Zoi.default([]),
              input_schema: Zoi.any(),
              output_schema: Zoi.any(),
              auth_profile: Zoi.atom(),
              auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              policies: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              scope_resolver: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              risk: Zoi.atom(),
              confirmation: Zoi.atom()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end

defmodule Jido.Connect.Jido.SensorProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Sensor` module."

  alias Jido.Connect.Field

  @schema Zoi.struct(
            __MODULE__,
            %{
              module: Zoi.module(),
              integration_module: Zoi.module(),
              integration_id: Zoi.atom(),
              trigger_id: Zoi.string(),
              name: Zoi.string(),
              label: Zoi.string(),
              description: Zoi.string(),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              resource: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              verb: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              data_classification: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              kind: Zoi.enum([:webhook, :poll]),
              runtime_mode: Zoi.enum([:poll, :metadata_only]) |> Zoi.default(:poll),
              config: Zoi.list(Field.schema()) |> Zoi.default([]),
              signal: Zoi.list(Field.schema()) |> Zoi.default([]),
              config_schema: Zoi.any(),
              signal_schema: Zoi.any(),
              signal_type: Zoi.string(),
              signal_source: Zoi.string(),
              auth_profile: Zoi.atom(),
              auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              policies: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              scope_resolver: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              interval_ms: Zoi.integer() |> Zoi.nullish()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end

defmodule Jido.Connect.Jido.PluginProjection do
  @moduledoc "Compile-time projection for one generated `Jido.Plugin` module."

  alias Jido.Connect.Jido.{ActionProjection, SensorProjection}

  @schema Zoi.struct(
            __MODULE__,
            %{
              module: Zoi.module(),
              integration_module: Zoi.module(),
              integration_id: Zoi.atom(),
              name: Zoi.string(),
              description: Zoi.string(),
              actions: Zoi.list(ActionProjection.schema()) |> Zoi.default([]),
              sensors: Zoi.list(SensorProjection.schema()) |> Zoi.default([])
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end

defmodule Jido.Connect.Jido.ToolAvailability do
  @moduledoc "Host-facing generated tool availability."

  @schema Zoi.struct(
            __MODULE__,
            %{
              tool: Zoi.string(),
              state:
                Zoi.enum([
                  :available,
                  :connection_required,
                  :missing_scopes,
                  :disabled_by_policy,
                  :configuration_error
                ]),
              connection_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              connection_selector: Zoi.any() |> Zoi.optional(),
              missing_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
