defmodule Jido.Connect.PostHog.Client do
  @moduledoc """
  PostHog REST client boundary.

  New code should prefer the API-area modules under `Jido.Connect.PostHog.Client.*`
  for a narrower dependency surface.
  """

  alias Jido.Connect.PostHog.Client.Transport

  @doc "Lists events for a project."
  def list_events(api_key, opts \\ [])
      when is_binary(api_key) and is_list(opts) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    params =
      []
      |> maybe_put_param(:limit, Keyword.get(opts, :limit))
      |> maybe_put_param(:offset, Keyword.get(opts, :offset))
      |> maybe_put_param(:event, Keyword.get(opts, :event))
      |> maybe_put_param(:distinct_id, Keyword.get(opts, :distinct_id))

    Req.get(request, url: "/api/projects/:project_id/events/", params: clean_params(params))
  end

  @doc "Fetches a single event by its UUID."
  def get_event(event_id, api_key, opts \\ [])
      when is_binary(event_id) and is_binary(api_key) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    Req.get(request,
      url: "/api/projects/:project_id/events/#{event_id}/",
      params: []
    )
  end

  @doc "Lists persons for a project."
  def list_persons(api_key, opts \\ [])
      when is_binary(api_key) and is_list(opts) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    params =
      []
      |> maybe_put_param(:limit, Keyword.get(opts, :limit))
      |> maybe_put_param(:offset, Keyword.get(opts, :offset))
      |> maybe_put_param(:search, Keyword.get(opts, :search))

    Req.get(request, url: "/api/projects/:project_id/persons/", params: clean_params(params))
  end

  @doc "Fetches a single person by their distinct ID."
  def get_person(distinct_id, api_key, opts \\ [])
      when is_binary(distinct_id) and is_binary(api_key) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    Req.get(request,
      url: "/api/projects/:project_id/persons/",
      params: [distinct_id: distinct_id]
    )
  end

  @doc "Lists insights for a project."
  def list_insights(api_key, opts \\ [])
      when is_binary(api_key) and is_list(opts) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    params =
      []
      |> maybe_put_param(:limit, Keyword.get(opts, :limit))
      |> maybe_put_param(:offset, Keyword.get(opts, :offset))

    Req.get(request, url: "/api/projects/:project_id/insights/", params: clean_params(params))
  end

  @doc "Fetches a single insight by its short ID."
  def get_insight(insight_id, api_key, opts \\ [])
      when is_binary(insight_id) and is_binary(api_key) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    Req.get(request,
      url: "/api/projects/:project_id/insights/#{insight_id}/",
      params: []
    )
  end

  # ---------------------------------------------------------------------------
  # Event capture
  # ---------------------------------------------------------------------------

  @doc "Captures a single event via the PostHog /e/ endpoint."
  def capture_event(api_key, event, distinct_id, opts \\ [])
      when is_binary(api_key) and is_binary(event) and is_binary(distinct_id) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))
    base_url = Keyword.get(opts, :base_url, Transport.base_url())

    # The capture endpoint is on the root, not under /api/projects/
    body = %{
      api_key: api_key,
      event: event,
      distinct_id: distinct_id,
      properties: Keyword.get(opts, :properties, %{}),
      timestamp: Keyword.get(opts, :timestamp)
    }

    Req.post(request,
      url: "#{base_url}/e/",
      json: clean_body(body)
    )
  end

  @doc "Captures a batch of events via the PostHog /e/ endpoint."
  def batch_capture_events(api_key, events, opts \\ [])
      when is_binary(api_key) and is_list(events) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))
    base_url = Keyword.get(opts, :base_url, Transport.base_url())

    body = %{
      api_key: api_key,
      batch: events
    }

    Req.post(request,
      url: "#{base_url}/e/",
      json: body
    )
  end

  # ---------------------------------------------------------------------------
  # Feature flags
  # ---------------------------------------------------------------------------

  @doc "Evaluates a feature flag for a given distinct ID via the /decide/ endpoint."
  def decide_feature_flag(flag_key, distinct_id, api_key, opts \\ [])
      when is_binary(flag_key) and is_binary(distinct_id) and is_binary(api_key) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))
    base_url = Keyword.get(opts, :base_url, Transport.base_url())

    body = %{
      token: api_key,
      distinct_id: distinct_id,
      groups: Keyword.get(opts, :groups, %{}),
      person_properties: Keyword.get(opts, :person_properties, %{})
    }

    Req.post(request,
      url: "#{base_url}/decide/?v=3",
      json: body
    )
  end

  @doc "Lists feature flags for a project."
  def list_feature_flags(api_key, opts \\ [])
      when is_binary(api_key) and is_list(opts) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    params =
      []
      |> maybe_put_param(:limit, Keyword.get(opts, :limit))
      |> maybe_put_param(:offset, Keyword.get(opts, :offset))

    Req.get(request,
      url: "/api/projects/:project_id/feature_flags/",
      params: clean_params(params)
    )
  end

  @doc "Fetches a single feature flag by its ID."
  def get_feature_flag(flag_id, api_key, opts \\ [])
      when is_binary(flag_id) and is_binary(api_key) do
    request = Transport.request(api_key, Keyword.take(opts, [:base_url, :req_options]))

    Req.get(request,
      url: "/api/projects/:project_id/feature_flags/#{flag_id}/",
      params: []
    )
  end

  @doc "Returns the configured or injected client module."
  def resolve(%{posthog_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key)
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, key, value), do: [{key, value} | params]

  defp clean_params(params), do: Enum.reverse(params)

  defp clean_body(body) do
    body
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
