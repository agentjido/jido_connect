defmodule Jido.Connect.Asana.Handlers.Actions.CreateStory do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         story_params <- build_story_params(input),
         {:ok, story} <- client.create_story(input.task_gid, token, story_params) do
      {:ok, %{story: story}}
    end
  end

  defp build_story_params(input) do
    %{}
    |> maybe_put("text", Map.get(input, :text))
    |> maybe_put("is_pinned", Map.get(input, :is_pinned))
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
