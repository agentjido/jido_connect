defmodule Jido.Connect.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link(
      [Jido.Connect.MCP.EndpointLeaseManager],
      strategy: :one_for_one,
      name: Jido.Connect.Supervisor
    )
  end
end
