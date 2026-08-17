defmodule Jido.Connect.Jira.Handlers.Actions.ListFieldSchemas do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <-
           client.list_field_schemas(request,
             expand: Map.get(input, :expand)
           ) do
      {:ok, result}
    end
  end
end
