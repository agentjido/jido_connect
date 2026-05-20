defmodule Jido.Connect.Asana.Client.Users do
  @moduledoc "Asana user API boundary."

  alias Jido.Connect.Asana.Client.{Response, Transport}

  @opt_fields ~w(name resource_type email photo workspaces)

  @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(user_gid, access_token, opts \\ [])
      when is_binary(user_gid) and is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> Map.put(:opt_fields, Keyword.get(opts, :opt_fields, Enum.join(@opt_fields, ",")))

    encoded_user = URI.encode(user_gid, &URI.char_unreserved?/1)

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/users/#{encoded_user}", params: params)
    |> Response.handle_user_response()
  end

  @spec list(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:workspace, Keyword.get(opts, :workspace))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(:opt_fields, Keyword.get(opts, :opt_fields, Enum.join(@opt_fields, ",")))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/users", params: params)
    |> Response.handle_user_list_response()
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)
end
