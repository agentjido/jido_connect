defmodule Jido.Connect.JidoSensorRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Jido.RuntimeContext
  alias Jido.Connect.Jido.SensorProjection

  def init(%SensorProjection{} = projection, config, context) when is_map(config) do
    state = %{
      projection: projection,
      config: config,
      context: context,
      checkpoint: context_value(context, :checkpoint),
      runtime_mode: projection.runtime_mode
    }

    case projection.kind do
      :poll -> {:ok, state, [{:schedule, projection.interval_ms || 300_000}]}
      _other -> {:ok, state}
    end
  end

  def handle_event(%SensorProjection{kind: :poll} = projection, :tick, state)
      when is_map(state) do
    context = Map.get(state, :context, %{})

    with {:ok, integration_context} <- RuntimeContext.integration_context(context),
         {:ok, integration_context} <-
           RuntimeContext.resolve_connection(integration_context, context, projection, %{
             trigger_id: projection.trigger_id
           }),
         {:ok, lease} <- RuntimeContext.credential_lease(context),
         {:ok, result} <-
           Connect.poll(
             projection.integration_module,
             projection.trigger_id,
             Map.get(state, :config, %{}),
             RuntimeContext.runtime_opts(context, integration_context, lease, %{
               checkpoint: Map.get(state, :checkpoint)
             })
           ) do
      signals = Enum.map(result.signals, &signal!(projection, &1))
      state = Map.put(state, :checkpoint, result.checkpoint)

      directives =
        Enum.map(signals, &{:emit, &1}) ++ [{:schedule, projection.interval_ms || 300_000}]

      {:ok, state, directives}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_event(%SensorProjection{runtime_mode: :metadata_only} = projection, event, _state) do
    {:error,
     Error.execution("Generated webhook sensor is metadata-only",
       phase: :webhook_runtime,
       details: %{
         trigger_id: projection.trigger_id,
         kind: projection.kind,
         runtime_mode: projection.runtime_mode,
         event_type: event_type(event)
       }
     )}
  end

  def handle_event(_projection, _event, state), do: {:ok, state}

  defp signal!(%SensorProjection{} = projection, payload) do
    Jido.Signal.new!(
      projection.signal_type,
      payload,
      source: projection.signal_source
    )
  end

  defp context_value(context, key) when is_map(context), do: Map.get(context, key)
  defp context_value(_context, _key), do: nil

  defp event_type(event) when is_struct(event), do: :struct
  defp event_type(event) when is_map(event), do: :map
  defp event_type(event) when is_tuple(event), do: :tuple
  defp event_type(event) when is_list(event), do: :list
  defp event_type(event) when is_atom(event), do: :atom
  defp event_type(event) when is_binary(event), do: :binary
  defp event_type(event) when is_number(event), do: :number
  defp event_type(_event), do: :other
end
