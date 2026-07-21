defmodule Jido.Connect.Zendesk.Client.Normalizer do
  @moduledoc "Zendesk REST response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.Zendesk.{
    Comment,
    Group,
    Organization,
    Pagination,
    Tag,
    Ticket,
    User
  }

  # ---------------------------------------------------------------------------
  # Ticket
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk ticket into a stable struct."
  @spec ticket(map()) :: {:ok, Ticket.t()} | {:error, term()}
  def ticket(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      url: Data.get(payload, "url"),
      subject: Data.get(payload, "subject"),
      description: Data.get(payload, "description"),
      status: Data.get(payload, "status"),
      type: Data.get(payload, "type"),
      priority: Data.get(payload, "priority"),
      requester_id: Data.get(payload, "requester_id"),
      assignee_id: Data.get(payload, "assignee_id"),
      group_id: Data.get(payload, "group_id"),
      organization_id: Data.get(payload, "organization_id"),
      tags: Data.get(payload, "tags", []),
      custom_fields: normalize_custom_fields(Data.get(payload, "custom_fields", [])),
      due_at: Data.get(payload, "due_at"),
      external_id: Data.get(payload, "external_id"),
      brand_id: Data.get(payload, "brand_id"),
      form_id: Data.get(payload, "ticket_form_id"),
      via: Data.get(payload, "via"),
      satisfaction_rating: Data.get(payload, "satisfaction_rating"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Ticket.new()
  end

  def ticket(_payload), do: {:error, :invalid_ticket_payload}

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk user into a stable struct."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      email: Data.get(payload, "email"),
      name: Data.get(payload, "name"),
      role: Data.get(payload, "role"),
      verified: Data.get(payload, "verified"),
      active: Data.get(payload, "active"),
      time_zone: Data.get(payload, "time_zone"),
      locale: Data.get(payload, "locale"),
      organization_id: Data.get(payload, "organization_id"),
      phone: Data.get(payload, "phone"),
      photo: Data.get(payload, "photo"),
      tags: Data.get(payload, "tags", []),
      external_id: Data.get(payload, "external_id"),
      alias: Data.get(payload, "alias"),
      details: Data.get(payload, "details"),
      notes: Data.get(payload, "notes"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # Organization
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk organization into a stable struct."
  @spec organization(map()) :: {:ok, Organization.t()} | {:error, term()}
  def organization(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      url: Data.get(payload, "url"),
      domain_names: Data.get(payload, "domain_names", []),
      details: Data.get(payload, "details"),
      notes: Data.get(payload, "notes"),
      group_id: Data.get(payload, "group_id"),
      tags: Data.get(payload, "tags", []),
      external_id: Data.get(payload, "external_id"),
      shared_tickets: Data.get(payload, "shared_tickets"),
      shared_comments: Data.get(payload, "shared_comments"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Organization.new()
  end

  def organization(_payload), do: {:error, :invalid_organization_payload}

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk ticket comment into a stable struct."
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      body: Data.get(payload, "body"),
      html_body: Data.get(payload, "html_body"),
      plain_body: Data.get(payload, "plain_body"),
      author_id: Data.get(payload, "author_id"),
      public: Data.get(payload, "public"),
      ticket_id: Data.get(payload, "ticket_id"),
      via: Data.get(payload, "via"),
      zendesk_metadata: Data.get(payload, "metadata"),
      attachments: Data.get(payload, "attachments", []),
      created_at: Data.get(payload, "created_at")
    }
    |> Data.compact()
    |> Comment.new()
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  # ---------------------------------------------------------------------------
  # Tag
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk tag entry into a stable struct."
  @spec tag(map()) :: {:ok, Tag.t()} | {:error, term()}
  def tag(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "name"),
      count: Data.get(payload, "count")
    }
    |> Data.compact()
    |> Tag.new()
  end

  def tag(_payload), do: {:error, :invalid_tag_payload}

  @doc "Normalizes a list of tag name strings into Tag structs."
  @spec tag_names([String.t()]) :: [{:ok, Tag.t()}]
  def tag_names(names) when is_list(names) do
    Enum.map(names, fn name -> Tag.new(%{name: name}) end)
  end

  # ---------------------------------------------------------------------------
  # Group
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk agent group into a stable struct."
  @spec group(map()) :: {:ok, Group.t()} | {:error, term()}
  def group(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      url: Data.get(payload, "url"),
      description: Data.get(payload, "description"),
      default: Data.get(payload, "default"),
      deleted: Data.get(payload, "deleted"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Group.new()
  end

  def group(_payload), do: {:error, :invalid_group_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Zendesk pagination envelope into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    meta = Data.get(payload, "meta", %{}) || %{}
    links = Data.get(payload, "links", %{}) || %{}

    %{
      after_cursor: Data.get(meta, "after_cursor"),
      before_cursor: Data.get(meta, "before_cursor"),
      has_more: Data.get(meta, "has_more"),
      next_url: Data.get(links, "next"),
      prev_url: Data.get(links, "prev"),
      next_page: Data.get(payload, "next_page"),
      previous_page: Data.get(payload, "previous_page"),
      count: Data.get(payload, "count")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_custom_fields(nil), do: []

  defp normalize_custom_fields(fields) when is_list(fields) do
    Enum.map(fields, fn field ->
      %{
        id: Data.get(field, "id"),
        value: Data.get(field, "value")
      }
      |> Data.compact()
    end)
  end

  defp normalize_custom_fields(_), do: []
end
