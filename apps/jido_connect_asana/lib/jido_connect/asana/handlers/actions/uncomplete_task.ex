defmodule Jido.Connect.Asana.Handlers.Actions.UncompleteTask do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, task} <- client.update_task(input.task_gid, token, %{"completed" => false}) do
      {:ok, %{task: task}}
    end
  end

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
