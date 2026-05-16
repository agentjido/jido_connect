defmodule Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers do
  @moduledoc false

  alias Jido.Connect.Airtable.Client

  def fetch_client(%{airtable_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(value), do: value
end
