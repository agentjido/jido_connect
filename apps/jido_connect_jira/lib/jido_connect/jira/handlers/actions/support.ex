defmodule Jido.Connect.Jira.Handlers.Actions.Support do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def call(runtime, fun) when is_function(fun, 2) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <- fun.(client, request) do
      {:ok, result}
    end
  end
end
