defmodule Jido.Connect.Calendly.Handlers.Actions.ListInvitees do
  @moduledoc false

  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, result} <- client.list_invitees(normalize_input(input), token) do
      {:ok, build_result(result)}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:count, 20)
  end

  defp build_result(result) do
    base = %{
      invitees: Enum.map(Map.get(result, :items, []), &ResourceHelpers.public_map/1)
    }

    case Map.get(result, :pagination) do
      nil -> base
      pagination -> Map.put(base, :pagination, ResourceHelpers.public_map(pagination))
    end
  end
end
