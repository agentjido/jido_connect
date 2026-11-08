defmodule Jido.Connect.GitHub.Handlers.Actions.Support do
  @moduledoc false

  alias Jido.Connect.Error

  def client_and_token(%{credentials: %{github_client: client} = credentials})
      when is_atom(client) do
    case Map.get(credentials, :access_token) do
      token when is_binary(token) and token != "" -> {:ok, client, token}
      _other -> {:error, Error.config("GitHub access token is required", key: :access_token)}
    end
  end

  def client_and_token(_runtime) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  def page(input, item_count, total_count \\ nil) do
    page = Map.get(input, :page, 1)
    per_page = Map.get(input, :per_page, 100)

    %{
      number: page,
      per_page: per_page,
      item_count: item_count,
      complete:
        item_count < per_page or (is_integer(total_count) and page * per_page >= total_count)
    }
  end
end
