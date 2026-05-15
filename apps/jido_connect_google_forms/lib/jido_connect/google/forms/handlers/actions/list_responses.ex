defmodule Jido.Connect.Google.Forms.Handlers.Actions.ListResponses do
  @moduledoc false

  alias Jido.Connect.Google.Forms.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_responses(input, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         responses: Enum.map(Map.get(result, :responses, []), &public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp fetch_client(%{google_forms_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()

  defp public_map(map) when is_map(map) do
    map
    |> Map.new(fn {key, value} -> {key, public_map(value)} end)
  end

  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  defp public_map(value), do: value
end
