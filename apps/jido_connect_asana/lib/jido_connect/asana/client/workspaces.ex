defmodule Jido.Connect.Asana.Client.Workspaces do
  @moduledoc "Asana workspace API boundary."

  alias Jido.Connect.Asana.Client.{Response, Transport}

  @opt_fields ~w(name resource_type is_organization email_domains)

  @spec list(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(:opt_fields, Keyword.get(opts, :opt_fields, Enum.join(@opt_fields, ",")))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/workspaces", params: params)
    |> Response.handle_workspace_list_response()
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)
end
