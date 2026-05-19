defmodule Jido.Connect.Intercom.Client do
  @moduledoc """
  Intercom REST client boundary.

  Provides methods for contact, conversation, admin, and team read/search
  operations against the Intercom REST API.

  ## Error normalization

  All methods return `{:ok, result}` or `{:error, %Jido.Connect.Error.ProviderError{}}`.
  Provider errors include normalized reason atoms:

  - `:unauthorized` (401) – missing or invalid token
  - `:forbidden` (403) – insufficient scopes
  - `:rate_limited` (429) – Intercom rate limit exceeded
  - `:server_error` (5xx) – transient Intercom failures
  - `:http_error` – other HTTP errors
  - `:invalid_response` – unexpected success payload shape
  """

  alias Jido.Connect.Intercom.Client.{Normalizer, Response, Transport}

  # ---------------------------------------------------------------------------
  # Contacts
  # ---------------------------------------------------------------------------

  @doc "Lists contacts with optional pagination and query filters."
  def list_contacts(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))
      |> maybe_put(:order, Keyword.get(opts, :order))
      |> maybe_put(:sort, Keyword.get(opts, :sort))
      |> maybe_put(:created_after, Keyword.get(opts, :created_after))
      |> maybe_put(:created_before, Keyword.get(opts, :created_before))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/contacts", params: params)
    |> Response.handle_list_response("data")
    |> normalize_list_result(:contact)
  end

  @doc "Searches contacts using an Intercom search query."
  def search_contacts(query, access_token, opts \\ [])
      when is_binary(query) and is_binary(access_token) and is_list(opts) do
    payload =
      %{"query" => %{"operator" => "AND", "value" => parse_query(query)}}
      |> maybe_put_payload(:pagination, build_search_pagination(opts))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.post(url: "/contacts/search", json: payload)
    |> Response.handle_search_response("data")
    |> normalize_list_result(:contact)
  end

  @doc "Fetches a single contact by ID."
  def get_contact(contact_id, access_token, opts \\ [])
      when is_binary(contact_id) and is_binary(access_token) and is_list(opts) do
    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/contacts/#{contact_id}")
    |> Response.handle_single_response("contact", &normalize_contact_item/1)
  end

  # ---------------------------------------------------------------------------
  # Conversations
  # ---------------------------------------------------------------------------

  @doc "Lists conversations with optional pagination and query filters."
  def list_conversations(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))
      |> maybe_put(:order, Keyword.get(opts, :order))
      |> maybe_put(:sort, Keyword.get(opts, :sort))
      |> maybe_put(:open, Keyword.get(opts, :open))
      |> maybe_put(:assignee_id, Keyword.get(opts, :assignee_id))
      |> maybe_put(:team_ids, Keyword.get(opts, :team_ids))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/conversations", params: params)
    |> Response.handle_list_response("conversations")
    |> normalize_list_result(:conversation)
  end

  @doc "Searches conversations using an Intercom search query."
  def search_conversations(query, access_token, opts \\ [])
      when is_binary(query) and is_binary(access_token) and is_list(opts) do
    payload =
      %{"query" => %{"operator" => "AND", "value" => parse_query(query)}}
      |> maybe_put_payload(:pagination, build_search_pagination(opts))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.post(url: "/conversations/search", json: payload)
    |> Response.handle_search_response("conversations")
    |> normalize_list_result(:conversation)
  end

  @doc "Fetches a single conversation by ID."
  def get_conversation(conversation_id, access_token, opts \\ [])
      when is_binary(conversation_id) and is_binary(access_token) and is_list(opts) do
    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/conversations/#{conversation_id}")
    |> Response.handle_single_response("conversation", &normalize_conversation_item/1)
  end

  # ---------------------------------------------------------------------------
  # Admins
  # ---------------------------------------------------------------------------

  @doc "Lists admins (teammates) with optional pagination."
  def list_admins(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/admins", params: params)
    |> Response.handle_list_response("admins")
    |> normalize_list_result(:admin)
  end

  # ---------------------------------------------------------------------------
  # Teams
  # ---------------------------------------------------------------------------

  @doc "Lists teams with optional pagination."
  def list_teams(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/teams", params: params)
    |> Response.handle_list_response("teams")
    |> normalize_list_result(:team)
  end

  # ---------------------------------------------------------------------------
  # Client resolution
  # ---------------------------------------------------------------------------

  @doc "Returns the configured or injected client module."
  def resolve(%{intercom_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp maybe_put_payload(payload, _key, nil), do: payload
  defp maybe_put_payload(payload, key, value), do: Map.put(payload, key, value)

  defp build_search_pagination(opts) do
    per_page = Keyword.get(opts, :per_page)
    starting_after = Keyword.get(opts, :starting_after)

    if per_page || starting_after do
      pagination =
        %{}
        |> maybe_put(:per_page, per_page)
        |> maybe_put(:starting_after, starting_after)

      pagination
    end
  end

  @doc false
  # Parses a simple "field:value field2:value2" query string into Intercom
  # search filter format. Each term becomes a `{field: ..., operator: ..., value: ...}` map.
  def parse_query(query) when is_binary(query) do
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&parse_term/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_term(term) do
    case String.split(term, ":", parts: 2) do
      [field, value] ->
        %{
          "field" => field,
          "operator" => "=",
          "value" => value
        }

      _ ->
        nil
    end
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :contact) do
    {:ok, %{result | items: Enum.map(items, &normalize_contact_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :conversation) do
    {:ok, %{result | items: Enum.map(items, &normalize_conversation_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :admin) do
    {:ok, %{result | items: Enum.map(items, &normalize_admin_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :team) do
    {:ok, %{result | items: Enum.map(items, &normalize_team_item/1)}}
  end

  defp normalize_list_result({:error, _} = error, _kind), do: error

  defp normalize_contact_item(payload) do
    case Normalizer.contact(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_conversation_item(payload) do
    case Normalizer.conversation(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_admin_item(payload) do
    case Normalizer.admin(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_team_item(payload) do
    case Normalizer.team(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end
end
