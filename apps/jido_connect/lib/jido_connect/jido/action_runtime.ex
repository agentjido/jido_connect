defmodule Jido.Connect.JidoActionRuntime do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.Jido.ActionProjection
  alias Jido.Connect.Jido.RuntimeContext

  def run(%ActionProjection{} = projection, params, agent_context) when is_map(params) do
    with {:ok, context} <- RuntimeContext.integration_context(agent_context),
         {:ok, context} <-
           RuntimeContext.resolve_connection(context, agent_context, projection, %{
             action_id: projection.action_id
           }) do
      Connect.invoke(
        projection.integration_module,
        projection.action_id,
        params,
        RuntimeContext.runtime_opts(agent_context, context)
      )
    end
  end
end
