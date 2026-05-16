defmodule Jido.Connect.Linear.Client.Normalizer do
  @moduledoc "Linear GraphQL response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.Linear.{
    Comment,
    Issue,
    Label,
    Pagination,
    State,
    Team,
    User
  }

  # ---------------------------------------------------------------------------
  # Issue
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear issue into a stable struct."
  @spec issue(map()) :: {:ok, Issue.t()} | {:error, term()}
  def issue(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      identifier: Data.get(payload, "identifier"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      state: normalize_state(Data.get(payload, "state")),
      priority: normalize_priority(Data.get(payload, "priority")),
      priority_label: Data.get(payload, "priorityLabel"),
      team: normalize_team_brief(Data.get(payload, "team")),
      assignee: normalize_user(Data.get(payload, "assignee")),
      creator: normalize_user(Data.get(payload, "creator")),
      labels: normalize_labels(Data.get(payload, "labels")),
      due_date: Data.get(payload, "dueDate"),
      estimate: Data.get(payload, "estimate"),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt")
    }
    |> Data.compact()
    |> Issue.new()
  end

  def issue(_payload), do: {:error, :invalid_issue_payload}

  # ---------------------------------------------------------------------------
  # Team
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear team into a stable struct."
  @spec team(map()) :: {:ok, Team.t()} | {:error, term()}
  def team(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      key: Data.get(payload, "key"),
      name: Data.get(payload, "name"),
      description: Data.get(payload, "description"),
      icon: Data.get(payload, "icon"),
      color: Data.get(payload, "color"),
      lead: normalize_user(Data.get(payload, "lead"))
    }
    |> Data.compact()
    |> Team.new()
  end

  def team(_payload), do: {:error, :invalid_team_payload}

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear user into a stable struct."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      display_name: Data.get(payload, "displayName"),
      email: Data.get(payload, "email"),
      avatar_url: Data.get(payload, "avatarUrl"),
      active: Data.get(payload, "active")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # State
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear workflow state into a stable struct."
  @spec state(map()) :: {:ok, State.t()} | {:error, term()}
  def state(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      type: Data.get(payload, "type"),
      color: Data.get(payload, "color"),
      description: Data.get(payload, "description")
    }
    |> Data.compact()
    |> State.new()
  end

  def state(_payload), do: {:error, :invalid_state_payload}

  # ---------------------------------------------------------------------------
  # Label
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear label into a stable struct."
  @spec label(map()) :: {:ok, Label.t()} | {:error, term()}
  def label(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      color: Data.get(payload, "color"),
      description: Data.get(payload, "description"),
      is_group: Data.get(payload, "isGroup"),
      parent: Data.get(payload, "parent")
    }
    |> Data.compact()
    |> Label.new()
  end

  def label(_payload), do: {:error, :invalid_label_payload}

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear comment into a stable struct."
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      body: Data.get(payload, "body"),
      author: normalize_user(Data.get(payload, "user")),
      parent_id: Data.get(payload, "parentId"),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt")
    }
    |> Data.compact()
    |> Comment.new()
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Linear GraphQL connection page info into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      has_next_page: Data.get(payload, "hasNextPage"),
      end_cursor: Data.get(payload, "endCursor"),
      total_count: Data.get(payload, "totalCount")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_state(nil), do: nil

  defp normalize_state(state) when is_map(state) do
    case state(state) do
      {:ok, s} -> s
      {:error, _} -> nil
    end
  end

  defp normalize_user(nil), do: nil

  defp normalize_user(user) when is_map(user) do
    case user(user) do
      {:ok, u} -> u
      {:error, _} -> nil
    end
  end

  defp normalize_team_brief(nil), do: nil

  defp normalize_team_brief(team) when is_map(team) do
    %{
      id: Data.get(team, "id"),
      key: Data.get(team, "key"),
      name: Data.get(team, "name")
    }
    |> Data.compact()
    |> Team.new()
    |> case do
      {:ok, t} -> t
      {:error, _} -> nil
    end
  end

  defp normalize_priority(nil), do: nil

  defp normalize_priority(priority) when is_integer(priority) do
    %{
      value: priority,
      label: priority_label(priority)
    }
  end

  defp normalize_priority(_), do: nil

  defp normalize_labels(%{"nodes" => nodes}) when is_list(nodes) do
    normalize_labels(nodes)
  end

  defp normalize_labels(labels) when is_list(labels) do
    labels
    |> Enum.map(&normalize_label/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_labels(_), do: []

  defp normalize_label(label) when is_map(label) do
    case label(label) do
      {:ok, l} -> l
      {:error, _} -> nil
    end
  end

  defp normalize_label(_), do: nil

  defp priority_label(0), do: "No priority"
  defp priority_label(1), do: "Urgent"
  defp priority_label(2), do: "High"
  defp priority_label(3), do: "Medium"
  defp priority_label(4), do: "Low"
  defp priority_label(_), do: "Unknown"
end
