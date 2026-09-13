defmodule Jido.Connect.MCP.Client do
  @moduledoc false

  @type client_ref :: GenServer.server() | term()
  @type result :: {:ok, map()} | {:error, term()}

  @callback list_tools(client_ref(), keyword()) :: result()
  @callback call_tool(client_ref(), String.t(), map(), keyword()) :: result()
end
