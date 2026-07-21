defmodule Jido.Connect.Asana.Handlers.Actions.CreateTask do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         task_params <- build_task_params(input),
         {:ok, task} <- client.create_task(token, task_params) do
      {:ok, %{task: task}}
    end
  end

  defp build_task_params(input) do
    %{}
    |> maybe_put("name", Map.get(input, :name))
    |> maybe_put("workspace", Map.get(input, :workspace_gid))
    |> maybe_put("notes", Map.get(input, :notes))
    |> maybe_put("assignee", Map.get(input, :assignee))
    |> maybe_put("due_on", Map.get(input, :due_on))
    |> maybe_put("due_at", Map.get(input, :due_at))
    |> maybe_put("start_on", Map.get(input, :start_on))
    |> maybe_put("projects", Map.get(input, :projects))
    |> maybe_put("tags", Map.get(input, :tags))
    |> maybe_put("parent", Map.get(input, :parent))
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
