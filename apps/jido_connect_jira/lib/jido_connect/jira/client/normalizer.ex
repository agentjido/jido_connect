defmodule Jido.Connect.Jira.Client.Normalizer do
  @moduledoc "Jira Cloud REST response normalization helpers."

  alias Jido.Connect.Data

  @doc "Normalizes a Jira issue into a consistent map shape."
  def normalize_issue(issue) when is_map(issue) do
    fields = Data.get(issue, "fields") || %{}

    %{
      key: Data.get(issue, "key"),
      id: Data.get(issue, "id"),
      url: Data.get(issue, "self"),
      summary: Data.get(fields, "summary"),
      status: normalize_status(Data.get(fields, "status")),
      issue_type: normalize_issue_type(Data.get(fields, "issuetype")),
      project: normalize_project(Data.get(fields, "project")),
      assignee: normalize_user(Data.get(fields, "assignee")),
      reporter: normalize_user(Data.get(fields, "reporter")),
      priority: normalize_priority(Data.get(fields, "priority")),
      labels: Data.get(fields, "labels", []),
      created_at: Data.get(fields, "created"),
      updated_at: Data.get(fields, "updated")
    }
    |> Data.compact()
  end

  def normalize_issue(_issue), do: nil

  defp normalize_status(nil), do: nil

  defp normalize_status(status) when is_map(status) do
    %{
      name: Data.get(status, "name"),
      id: Data.get(status, "id")
    }
    |> Data.compact()
  end

  defp normalize_issue_type(nil), do: nil

  defp normalize_issue_type(type) when is_map(type) do
    %{
      name: Data.get(type, "name"),
      id: Data.get(type, "id"),
      subtask: Data.get(type, "subtask")
    }
    |> Data.compact()
  end

  defp normalize_project(nil), do: nil

  defp normalize_project(project) when is_map(project) do
    %{
      key: Data.get(project, "key"),
      name: Data.get(project, "name"),
      id: Data.get(project, "id")
    }
    |> Data.compact()
  end

  defp normalize_user(nil), do: nil

  defp normalize_user(user) when is_map(user) do
    %{
      account_id: Data.get(user, "accountId"),
      display_name: Data.get(user, "displayName"),
      active: Data.get(user, "active")
    }
    |> Data.compact()
  end

  defp normalize_priority(nil), do: nil

  defp normalize_priority(priority) when is_map(priority) do
    %{
      name: Data.get(priority, "name"),
      id: Data.get(priority, "id")
    }
    |> Data.compact()
  end
end
