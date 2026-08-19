defmodule Jido.Connect.Jira.Client.Plans do
  @moduledoc "Jira Plans REST operations. All operations require Jira administration access."

  alias Jido.Connect.Data
  alias Jido.Connect.Jira.Client.{Normalizer.Plan, Request, Transport}

  @base "/rest/api/3/plans/plan"

  def list(%Request{} = request, opts \\ []) do
    params =
      %{
        includeArchived: Keyword.get(opts, :include_archived, false),
        includeTrashed: Keyword.get(opts, :include_trashed, false),
        maxResults: Keyword.get(opts, :limit, 50)
      }
      |> maybe_put(:cursor, Keyword.get(opts, :cursor))

    request
    |> req()
    |> Req.get(url: Request.url(request, @base), params: params)
    |> normalize(&Plan.list(&1, opts), "Jira plan list response was invalid")
  end

  def get(id, %Request{} = request) when is_integer(id) do
    request
    |> req()
    |> Req.get(url: Request.url(request, "#{@base}/#{id}"))
    |> normalize(&Plan.one/1, "Jira plan response was invalid")
  end

  def create(attrs, %Request{} = request) when is_map(attrs) do
    body =
      %{
        name: Map.fetch!(attrs, :name),
        issueSources: Map.fetch!(attrs, :issue_sources),
        scheduling: Map.fetch!(attrs, :scheduling)
      }
      |> maybe_put(:leadAccountId, Map.get(attrs, :lead_account_id))
      |> maybe_put(:exclusionRules, Map.get(attrs, :exclusion_rules))
      |> maybe_put(:crossProjectReleases, Map.get(attrs, :cross_project_releases))
      |> maybe_put(:customFields, Map.get(attrs, :custom_fields))
      |> maybe_put(:permissions, Map.get(attrs, :permissions))

    response =
      request
      |> req()
      |> Req.post(url: Request.url(request, @base), json: body)

    with {:ok, id} <-
           normalize(response, &Plan.created_id/1, "Jira plan create response was invalid",
             mutation?: true
           ) do
      {:ok, %{id: id, name: attrs.name, created: true}}
    end
  end

  def update(id, attrs, %Request{} = request) when is_integer(id) and is_map(attrs) do
    patches = patches(attrs)

    response =
      request
      |> req()
      |> Req.put(
        url: Request.url(request, "#{@base}/#{id}"),
        headers: [{"content-type", "application/json-patch+json"}],
        json: patches
      )

    with {:ok, _body} <- success(response, "Jira plan update request failed", mutation?: true) do
      {:ok,
       %{
         id: Integer.to_string(id),
         updated: true,
         changed_fields: attrs |> Map.keys() |> Enum.map(&Atom.to_string/1) |> Enum.sort()
       }}
    end
  end

  def duplicate(id, name, %Request{} = request) when is_integer(id) and is_binary(name) do
    response =
      request
      |> req()
      |> Req.post(url: Request.url(request, "#{@base}/#{id}/duplicate"), json: %{name: name})

    with {:ok, duplicated_id} <-
           normalize(response, &Plan.created_id/1, "Jira plan duplicate response was invalid",
             mutation?: true
           ) do
      {:ok,
       %{
         id: duplicated_id,
         source_plan_id: Integer.to_string(id),
         name: name,
         duplicated: true
       }}
    end
  end

  def archive(id, %Request{} = request), do: lifecycle(id, "archive", request)
  def trash(id, %Request{} = request), do: lifecycle(id, "trash", request)

  defp lifecycle(id, operation, request) when is_integer(id) do
    response =
      request
      |> req()
      |> Req.put(url: Request.url(request, "#{@base}/#{id}/#{operation}"))

    with {:ok, _body} <-
           success(response, "Jira plan #{operation} request failed", mutation?: true) do
      {:ok, %{id: Integer.to_string(id), updated: true}}
    end
  end

  defp patches(attrs) do
    direct = [
      {:name, "/name"},
      {:lead_account_id, "/leadAccountId"},
      {:issue_sources, "/issueSources"},
      {:cross_project_releases, "/crossProjectReleases"},
      {:custom_fields, "/customFields"},
      {:permissions, "/permissions"}
    ]

    direct_patches = patch_fields(attrs, direct)

    scheduling =
      patch_nested(Data.get(attrs, :scheduling), "/scheduling", [
        {:estimation, "estimation"},
        {:startDate, "startDate"},
        {:endDate, "endDate"},
        {:inferredDates, "inferredDates"},
        {:dependencies, "dependencies"}
      ])

    exclusions =
      patch_nested(Data.get(attrs, :exclusion_rules), "/exclusionRules", [
        {:numberOfDaysToShowCompletedIssues, "numberOfDaysToShowCompletedIssues"},
        {:issueIds, "issueIds"},
        {:workStatusIds, "workStatusIds"},
        {:workStatusCategoryIds, "workStatusCategoryIds"},
        {:issueTypeIds, "issueTypeIds"},
        {:releaseIds, "releaseIds"}
      ])

    direct_patches ++ scheduling ++ exclusions
  end

  defp patch_fields(attrs, fields) do
    Enum.flat_map(fields, fn {key, path} ->
      case fetch(attrs, key) do
        {:ok, value} -> [%{op: "replace", path: path, value: value}]
        :error -> []
      end
    end)
  end

  defp patch_nested(nil, _prefix, _fields), do: []

  defp patch_nested(value, prefix, fields) do
    patch_fields(value, Enum.map(fields, fn {key, path} -> {key, prefix <> "/" <> path} end))
  end

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(map, Atom.to_string(key))
    end
  end

  defp req(request), do: Transport.request(request, req_options: [retry: false])

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

  defp success({:ok, %{status: status, body: body}}, _message, _opts) when status in 200..299,
    do: {:ok, body}

  defp success(response, message, opts),
    do: Transport.handle_error_response(response, Keyword.put(opts, :message, message))

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
