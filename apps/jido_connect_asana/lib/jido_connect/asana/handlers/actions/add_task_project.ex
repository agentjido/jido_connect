defmodule Jido.Connect.Asana.Handlers.Actions.AddTaskProject do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.add_task_project(input.task_gid, token, input.project_gid) do
      {:ok, %{result: result}}
    end
  end

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
