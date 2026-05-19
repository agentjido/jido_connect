defmodule Jido.Connect.Zendesk.Client do
  @moduledoc """
  Zendesk REST client boundary.

  Provides methods for ticket read/search, user listing, organization
  listing, and ticket comment listing against the Zendesk REST API v2.

  New code should prefer the API-area modules under
  `Jido.Connect.Zendesk.Client.*` for a narrower dependency surface.
  """

  alias Jido.Connect.Zendesk.Client.{Normalizer, Response, Transport}

  # ---------------------------------------------------------------------------
  # Tickets
  # ---------------------------------------------------------------------------

  @doc "Lists tickets with optional pagination and sorting."
  def list_tickets(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:page, Keyword.get(opts, :page))
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))
      |> maybe_put(:sort_by, Keyword.get(opts, :sort_by))
      |> maybe_put(:sort_order, Keyword.get(opts, :sort_order))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/tickets.json", params: params)
    |> Response.handle_list_response("tickets")
    |> normalize_list_result(:ticket)
  end

  @doc "Searches tickets using a Zendesk query string."
  def search_tickets(query, access_token, opts \\ [])
      when is_binary(query) and is_binary(access_token) and is_list(opts) do
    params =
      %{query: query}
      |> maybe_put(:page, Keyword.get(opts, :page))
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))
      |> maybe_put(:sort_by, Keyword.get(opts, :sort_by))
      |> maybe_put(:sort_order, Keyword.get(opts, :sort_order))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/search.json", params: params)
    |> Response.handle_search_response("results")
    |> normalize_list_result(:ticket)
  end

  @doc "Fetches a single ticket by ID."
  def get_ticket(ticket_id, access_token, opts \\ [])
      when is_integer(ticket_id) and is_binary(access_token) and is_list(opts) do
    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/tickets/#{ticket_id}.json")
    |> Response.handle_ticket_response()
  end

  # ---------------------------------------------------------------------------
  # Ticket Comments
  # ---------------------------------------------------------------------------

  @doc "Lists comments for a given ticket."
  def list_ticket_comments(ticket_id, access_token, opts \\ [])
      when is_integer(ticket_id) and is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:page, Keyword.get(opts, :page))
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/tickets/#{ticket_id}/comments.json", params: params)
    |> Response.handle_list_response("comments")
    |> normalize_list_result(:comment)
  end

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------

  @doc "Lists users with optional pagination and role filter."
  def list_users(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:page, Keyword.get(opts, :page))
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))
      |> maybe_put(:role, Keyword.get(opts, :role))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/users.json", params: params)
    |> Response.handle_list_response("users")
    |> normalize_list_result(:user)
  end

  # ---------------------------------------------------------------------------
  # Organizations
  # ---------------------------------------------------------------------------

  @doc "Lists organizations with optional pagination."
  def list_organizations(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{}
      |> maybe_put(:page, Keyword.get(opts, :page))
      |> maybe_put(:per_page, Keyword.get(opts, :per_page))

    access_token
    |> Transport.request(base_url: Keyword.get(opts, :base_url))
    |> Req.get(url: "/api/v2/organizations.json", params: params)
    |> Response.handle_list_response("organizations")
    |> normalize_list_result(:organization)
  end

  # ---------------------------------------------------------------------------
  # Client resolution
  # ---------------------------------------------------------------------------

  @doc "Returns the configured or injected client module."
  def resolve(%{zendesk_client: client}) when is_atom(client), do: client
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

  defp normalize_list_result({:ok, %{items: items} = result}, :ticket) do
    {:ok, %{result | items: Enum.map(items, &normalize_ticket_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :comment) do
    {:ok, %{result | items: Enum.map(items, &normalize_comment_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :user) do
    {:ok, %{result | items: Enum.map(items, &normalize_user_item/1)}}
  end

  defp normalize_list_result({:ok, %{items: items} = result}, :organization) do
    {:ok, %{result | items: Enum.map(items, &normalize_organization_item/1)}}
  end

  defp normalize_list_result({:error, _} = error, _kind), do: error

  defp normalize_ticket_item(payload) do
    case Normalizer.ticket(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_comment_item(payload) do
    case Normalizer.comment(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_user_item(payload) do
    case Normalizer.user(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_organization_item(payload) do
    case Normalizer.organization(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end
end
