defmodule Jido.Connect.GitHub.Client.Account do
  @moduledoc "GitHub user, installation, and rate-state read boundary."

  alias Jido.Connect.GitHub.Client.{Pagination, Response, Transport}

  def get_user(access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/user")
    |> Response.handle_user_response()
  end

  def list_user_installations(params, access_token)
      when is_map(params) and is_binary(access_token) do
    with {:ok, page} <- Pagination.validate(params),
         {:ok, result} <-
           access_token
           |> Transport.request()
           |> Req.get(url: "/user/installations", params: Map.to_list(page))
           |> Response.handle_user_installation_list_response() do
      {:ok,
       Map.put(
         result,
         :page,
         Pagination.metadata(page, length(result.installations), result.total_count)
       )}
    end
  end

  def list_user_installation_repositories(installation_id, params, access_token)
      when is_integer(installation_id) and is_map(params) and is_binary(access_token) do
    with {:ok, page} <- Pagination.validate(params),
         {:ok, result} <-
           access_token
           |> Transport.request()
           |> Req.get(
             url: "/user/installations/#{installation_id}/repositories",
             params: Map.to_list(page)
           )
           |> Response.handle_repository_list_response() do
      {:ok,
       Map.put(
         result,
         :page,
         Pagination.metadata(page, length(result.repositories), result.total_count)
       )}
    end
  end

  def get_rate_limit(access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/rate_limit")
    |> Response.handle_rate_limit_response()
  end
end
