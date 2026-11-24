defmodule Jido.Connect.JidoActionRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Jido.ActionProjection
  alias Jido.Connect.Jido.RuntimeContext
  alias Jido.Connect.Plugin

  def run(%ActionProjection{} = projection, params, agent_context) when is_map(params) do
    with {:ok, access} <- Plugin.action_context(agent_context, projection.module),
         {:ok, context} <- RuntimeContext.integration_context(access),
         {:ok, context} <-
           RuntimeContext.resolve_connection(context, access, projection, %{
             action_id: projection.action_id
           }) do
      Connect.invoke(
        projection.integration_module,
        projection.action_id,
        params,
        RuntimeContext.runtime_opts(access, context)
      )
    end
  end
end
