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
end
