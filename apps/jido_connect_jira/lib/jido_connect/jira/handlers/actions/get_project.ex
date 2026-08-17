defmodule Jido.Connect.Jira.Handlers.Actions.GetProject do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, project} <- client.get_project(input.project_key, request) do
      {:ok, project}
    end
  end
end
