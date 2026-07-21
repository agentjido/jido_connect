defmodule Jido.Connect.PostHog.Client.Normalizer do
  @moduledoc "PostHog REST response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.PostHog.{
    Event,
    FeatureFlag,
    FlagEvaluation,
    Insight,
    Pagination,
    Person,
    QueryResult
  }

  # ---------------------------------------------------------------------------
  # Event
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog event into a stable struct."
  @spec event(map()) :: {:ok, Event.t()} | {:error, term()}
  def event(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      event: Data.get(payload, "event"),
      distinct_id: Data.get(payload, "distinct_id"),
      properties: Data.get(payload, "properties", %{}),
      timestamp: Data.get(payload, "timestamp")
    }
    |> Data.compact()
    |> Event.new()
  end

  def event(_payload), do: {:error, :invalid_event_payload}

  # ---------------------------------------------------------------------------
  # Person
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog person into a stable struct."
  @spec person(map()) :: {:ok, Person.t()} | {:error, term()}
  def person(payload) when is_map(payload) do
    properties = Data.get(payload, "properties", %{})

    %{
      id: Data.get(payload, "id"),
      distinct_ids: Data.get(payload, "distinct_ids", []),
      name: Data.get(properties, "name") || Data.get(payload, "name"),
      email: Data.get(properties, "email") || Data.get(payload, "email"),
      properties: properties,
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> Person.new()
  end

  def person(_payload), do: {:error, :invalid_person_payload}

  # ---------------------------------------------------------------------------
  # FeatureFlag
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog feature flag into a stable struct."
  @spec feature_flag(map()) :: {:ok, FeatureFlag.t()} | {:error, term()}
  def feature_flag(payload) when is_map(payload) do
    %{
      id: stringify_id(Data.get(payload, "id")),
      key: Data.get(payload, "key"),
      name: Data.get(payload, "name"),
      description: Data.get(payload, "description"),
      active: Data.get(payload, "active"),
      rollout_percentage: Data.get(payload, "rollout_percentage"),
      filters: Data.get(payload, "filters"),
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> FeatureFlag.new()
  end

  def feature_flag(_payload), do: {:error, :invalid_feature_flag_payload}

  # ---------------------------------------------------------------------------
  # FlagEvaluation
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog feature flag evaluation result into a stable struct."
  @spec flag_evaluation(map()) :: {:ok, FlagEvaluation.t()} | {:error, term()}
  def flag_evaluation(payload) when is_map(payload) do
    %{
      flag_key: Data.get(payload, "flag_key") || Data.get(payload, "key"),
      enabled: Data.get(payload, "enabled"),
      variant: Data.get(payload, "variant"),
      reason: Data.get(payload, "reason"),
      payload: Data.get(payload, "payload")
    }
    |> Data.compact()
    |> FlagEvaluation.new()
  end

  def flag_evaluation(_payload), do: {:error, :invalid_flag_evaluation_payload}

  # ---------------------------------------------------------------------------
  # Insight
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog insight into a stable struct."
  @spec insight(map()) :: {:ok, Insight.t()} | {:error, term()}
  def insight(payload) when is_map(payload) do
    %{
      id: stringify_id(Data.get(payload, "id")),
      short_id: Data.get(payload, "short_id"),
      name: Data.get(payload, "name"),
      derived_name: Data.get(payload, "derived_name"),
      type: Data.get(payload, "type") || Data.get(payload, "kind"),
      description: Data.get(payload, "description"),
      result: Data.get(payload, "result"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Insight.new()
  end

  def insight(_payload), do: {:error, :invalid_insight_payload}

  # ---------------------------------------------------------------------------
  # QueryResult
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog HogQL query result into a stable struct."
  @spec query_result(map()) :: {:ok, QueryResult.t()} | {:error, term()}
  def query_result(payload) when is_map(payload) do
    %{
      query: Data.get(payload, "query"),
      columns: Data.get(payload, "columns", []),
      results: Data.get(payload, "results", []),
      has_more: Data.get(payload, "has_more")
    }
    |> Data.compact()
    |> QueryResult.new()
  end

  def query_result(_payload), do: {:error, :invalid_query_result_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a PostHog REST API pagination envelope into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      next: Data.get(payload, "next"),
      previous: Data.get(payload, "previous"),
      count: Data.get(payload, "count")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp stringify_id(id) when is_integer(id), do: Integer.to_string(id)
  defp stringify_id(id) when is_binary(id), do: id
  defp stringify_id(_), do: nil
end
