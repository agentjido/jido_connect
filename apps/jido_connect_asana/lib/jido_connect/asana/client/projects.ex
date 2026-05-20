defmodule Jido.Connect.Asana.Client.Projects do
  @moduledoc "Asana project API boundary."

  alias Jido.Connect.Asana.Client.{Response, Transport}

  @opt_fields ~w(name resource_type color archived public due_date due_on start_on notes current_status default_view workspace team owner created_at modified_at)

  @spec list(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:workspace, Keyword.get(opts, :workspace))
      |> maybe_put(:team, Keyword.get(opts, :team))
      |> maybe_put(:archived, Keyword.get(opts, :archived))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(:opt_fields, Keyword.get(opts, :opt_fields, Enum.join(@opt_fields, ",")))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/projects", params: params)
    |> Response.handle_project_list_response()
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)
end
