defmodule Jido.Connect.Jira.Client.Filters do
  @moduledoc "Jira saved-filter, column, and share-permission REST operations."

  alias Jido.Connect.Jira.Client.{Normalizer.Filter, Request, Transport}
  alias Jido.Connect.Provider.Transport, as: ProviderTransport

  @expand "description,owner,jql,viewUrl,favourite,sharePermissions"

  def list(%Request{} = request, opts \\ []) do
    params =
      %{
        startAt: Keyword.get(opts, :offset, 0),
        maxResults: Keyword.get(opts, :limit, 50),
        orderBy: "name",
        expand: @expand
      }
      |> maybe_put(:filterName, Keyword.get(opts, :name))
      |> maybe_put(:accountId, Keyword.get(opts, :owner_account_id))

    request
    |> get("/rest/api/3/filter/search", params)
    |> normalize(&Filter.list(&1, opts), "Jira filter list response was invalid")
  end

  def get(id, %Request{} = request) when is_integer(id) do
    request
    |> get("/rest/api/3/filter/#{id}", %{expand: @expand})
    |> normalize(&Filter.one/1, "Jira filter response was invalid")
  end

  def create(attrs, %Request{} = request) when is_map(attrs) do
    body =
      %{
        name: Map.fetch!(attrs, :name),
        jql: Map.fetch!(attrs, :query),
        favourite: Map.get(attrs, :favorite, false)
      }
      |> maybe_put(:description, Map.get(attrs, :description))

    request
    |> post("/rest/api/3/filter", body)
    |> normalize(&Filter.one/1, "Jira filter create response was invalid", mutation?: true)
  end

  def update(id, attrs, %Request{} = request) when is_integer(id) and is_map(attrs) do
    body =
      %{
        name: Map.fetch!(attrs, :name),
        jql: Map.fetch!(attrs, :query)
      }
      |> maybe_put(:description, Map.get(attrs, :description))
      |> maybe_put(:favourite, Map.get(attrs, :favorite))

    request
    |> put("/rest/api/3/filter/#{id}", body)
    |> normalize(&Filter.one/1, "Jira filter update response was invalid", mutation?: true)
  end

  def get_columns(id, %Request{} = request) when is_integer(id) do
    request
    |> get("/rest/api/3/filter/#{id}/columns", %{})
    |> normalize(&Filter.columns(&1, id), "Jira filter column response was invalid")
  end

  def update_columns(id, columns, %Request{} = request)
      when is_integer(id) and is_list(columns) do
    path = "/rest/api/3/filter/#{id}/columns"

    with {:ok, _body} <- write(request, :put, path, %{columns: columns}, mutation?: true),
         response <- get(request, path, %{}),
         {:ok, result} <-
           normalize(response, &Filter.columns(&1, id), "Jira filter column response was invalid",
             mutation?: true
           ) do
      {:ok, Map.put(result, :updated, true)}
    end
  end

  def replace_shares(id, attrs, %Request{} = request)
      when is_integer(id) and is_map(attrs) do
    path = "/rest/api/3/filter/#{id}/permission"
    scope = Map.fetch!(attrs, :scope)

    with {:ok, current} <- read_body(request, path),
         {:ok, permission_ids} <- normalize_permission_ids(current),
         {:ok, desired} <- desired_permissions(attrs, request),
         :ok <- remove_permissions(permission_ids, path, request),
         :ok <- add_permissions(desired, path, request),
         {:ok, final} <- read_body(request, path, mutation?: true),
         {:ok, result} <- normalize_permissions(final, id, scope, mutation?: true) do
      {:ok, result}
    end
  end

  defp desired_permissions(%{scope: "private"}, _request), do: {:ok, []}

  defp desired_permissions(%{scope: "authenticated"}, _request),
    do: {:ok, [%{type: "authenticated", rights: 1}]}

  defp desired_permissions(%{scope: "public"}, _request),
    do: {:ok, [%{type: "global", rights: 1}]}

  defp desired_permissions(%{scope: "groups", group_ids: ids}, _request),
    do: {:ok, Enum.map(ids, &%{type: "group", groupId: &1, rights: 1})}

  defp desired_permissions(%{scope: "projects", projects: projects}, request) do
    Enum.reduce_while(projects, {:ok, []}, fn project, {:ok, acc} ->
      case read_body(request, "/rest/api/3/project/#{path_segment(project)}") do
        {:ok, raw} ->
          case Filter.project_id(raw) do
            {:ok, id} ->
              {:cont, {:ok, [%{type: "project", projectId: id, rights: 1} | acc]}}

            :error ->
              {:halt,
               Transport.invalid_success_response("Jira project response was invalid", raw)}
          end

        {:error, _error} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, permissions} -> {:ok, Enum.reverse(permissions)}
      {:error, _error} = error -> error
    end
  end

  defp remove_permissions(ids, path, request) do
    Enum.reduce_while(ids, :ok, fn id, :ok ->
      case write(request, :delete, "#{path}/#{id}", nil, mutation?: true) do
        {:ok, _body} -> {:cont, :ok}
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp add_permissions(permissions, path, request) do
    Enum.reduce_while(permissions, :ok, fn permission, :ok ->
      case write(request, :post, path, permission, mutation?: true) do
        {:ok, _body} -> {:cont, :ok}
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_permission_ids(body) do
    case Filter.permission_ids(body) do
      {:ok, ids} -> {:ok, ids}
      :error -> Transport.invalid_success_response("Jira filter share response was invalid", body)
    end
  end

  defp normalize_permissions(body, id, scope, opts) do
    case Filter.permissions(body, id, scope) do
      {:ok, result} ->
        {:ok, result}

      :error ->
        Transport.invalid_success_response("Jira filter share response was invalid", body, opts)
    end
  end

  defp read_body(request, path, opts \\ []) do
    request
    |> get(path, %{})
    |> success_body(Keyword.put_new(opts, :message, "Jira filter share request failed"))
  end

  defp get(request, path, params) do
    request
    |> Transport.request(req_options: [retry: false])
    |> Req.get(url: Request.url(request, path), params: params)
  end

  defp post(request, path, body) do
    request
    |> Transport.request(req_options: [retry: false])
    |> Req.post(url: Request.url(request, path), json: body)
  end

  defp put(request, path, body) do
    request
    |> Transport.request(req_options: [retry: false])
    |> Req.put(url: Request.url(request, path), json: body)
  end

  defp write(request, method, path, body, opts) do
    url = Request.url(request, path)
    request = Transport.request(request, req_options: [retry: false])
    request_opts = [url: url]
    request_opts = if is_nil(body), do: request_opts, else: Keyword.put(request_opts, :json, body)

    response = ProviderTransport.request(request, method, request_opts)

    success_body(response, Keyword.put_new(opts, :message, "Jira filter share request failed"))
  end

  defp success_body({:ok, %{status: status, body: body}}, _opts) when status in 200..299,
    do: {:ok, body}

  defp success_body(response, opts), do: Transport.handle_error_response(response, opts)

  defp normalize(response, fun, message, opts \\ []) do
    case response do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        case fun.(body) do
          {:ok, normalized} -> {:ok, normalized}
          :error -> Transport.invalid_success_response(message, body, opts)
        end

      other ->
        Transport.handle_error_response(other, Keyword.put(opts, :message, message))
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
