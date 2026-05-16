defmodule Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers do
  @moduledoc false

  alias Jido.Connect.Salesforce.Client

  def fetch_client(%{salesforce_client: client}) when is_atom(client), do: {:ok, client}
  def fetch_client(_credentials), do: {:ok, Client}

  def credential_token(credentials) do
    Map.get(credentials, :access_token) || Map.get(credentials, :api_key)
  end

  def instance_url(credentials) do
    Map.get(credentials, :instance_url) || Client.Transport.default_instance_url()
  end

  def public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  def public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  def public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  def public_map(value), do: value
end
