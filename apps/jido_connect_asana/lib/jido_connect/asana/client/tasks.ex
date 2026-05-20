defmodule Jido.Connect.Asana.Client.Tasks do
  @moduledoc "Asana task API boundary."

  alias Jido.Connect.Asana.Client.{Response, Transport}

  @list_opt_fields ~w(name resource_type assignee assignee_status completed completed_at due_on due_at start_on notes num_hearts num_likes parent workspace projects tags memberships custom_fields created_at modified_at)

  @get_opt_fields ~w(name resource_type assignee assignee_status completed completed_at due_on due_at start_on start_at notes html_notes num_hearts num_likes parent workspace projects tags memberships custom_fields created_at modified_at)

  @search_opt_fields @get_opt_fields

  @spec list(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def list(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:project, Keyword.get(opts, :project))
      |> maybe_put(:workspace, Keyword.get(opts, :workspace))
      |> maybe_put(:assignee, Keyword.get(opts, :assignee))
      |> maybe_put(:completed_since, Keyword.get(opts, :completed_since))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(
        :opt_fields,
        Keyword.get(opts, :opt_fields, Enum.join(@list_opt_fields, ","))
      )

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/tasks", params: params)
    |> Response.handle_task_list_response()
  end

  @spec get(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(task_gid, access_token, opts \\ [])
      when is_binary(task_gid) and is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> Map.put(
        :opt_fields,
        Keyword.get(opts, :opt_fields, Enum.join(@get_opt_fields, ","))
      )

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/tasks/#{URI.encode(task_gid, &URI.char_unreserved?/1)}", params: params)
    |> Response.handle_task_response()
  end

  @spec search(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def search(workspace_gid, access_token, opts \\ [])
      when is_binary(workspace_gid) and is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:text, Keyword.get(opts, :query))
      |> maybe_put(:assignee, Keyword.get(opts, :assignee))
      |> maybe_put(:projects, Keyword.get(opts, :projects))
      |> maybe_put(:sections, Keyword.get(opts, :sections))
      |> maybe_put(:completed, Keyword.get(opts, :completed))
      |> maybe_put(:due_on, Keyword.get(opts, :due_on))
      |> maybe_put(:due_before, Keyword.get(opts, :due_before))
      |> maybe_put(:due_after, Keyword.get(opts, :due_after))
      |> maybe_put(:tags, Keyword.get(opts, :tags))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> Map.put(
        :opt_fields,
        Keyword.get(opts, :opt_fields, Enum.join(@search_opt_fields, ","))
      )

    encoded_workspace = URI.encode(workspace_gid, &URI.char_unreserved?/1)

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/workspaces/#{encoded_workspace}/tasks/search", params: params)
    |> Response.handle_task_list_response()
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)
end
