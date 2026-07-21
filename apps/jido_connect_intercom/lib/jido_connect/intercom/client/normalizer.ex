defmodule Jido.Connect.Intercom.Client.Normalizer do
  @moduledoc "Intercom REST API response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.Intercom.{
    Admin,
    Company,
    Contact,
    Conversation,
    ConversationPart,
    Pagination,
    Tag,
    Team
  }

  # ---------------------------------------------------------------------------
  # Contact
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom contact into a stable struct."
  @spec contact(map()) :: {:ok, Contact.t()} | {:error, term()}
  def contact(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      workspace_id: Data.get(payload, "workspace_id"),
      external_id: Data.get(payload, "external_id"),
      name: Data.get(payload, "name"),
      email: Data.get(payload, "email"),
      phone: Data.get(payload, "phone"),
      avatar: Data.get(payload, "avatar"),
      type: Data.get(payload, "type"),
      role: Data.get(payload, "role"),
      has_hard_bounced: Data.get(payload, "has_hard_bounced"),
      marked_email_as_spam: Data.get(payload, "marked_email_as_spam"),
      unsubscribed_from_emails: Data.get(payload, "unsubscribed_from_emails"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      signed_up_at: Data.get(payload, "signed_up_at"),
      last_seen_at: Data.get(payload, "last_seen_at"),
      last_replied_at: Data.get(payload, "last_replied_at"),
      last_email_opened_at: Data.get(payload, "last_email_opened_at"),
      last_contacted_at: Data.get(payload, "last_contacted_at"),
      browser: Data.get(payload, "browser"),
      browser_version: Data.get(payload, "browser_version"),
      os: Data.get(payload, "os"),
      location: Data.get(payload, "location"),
      tags: Data.get(payload, "tags"),
      companies: Data.get(payload, "companies"),
      custom_attributes: Data.get(payload, "custom_attributes")
    }
    |> Data.compact()
    |> Contact.new()
  end

  def contact(_payload), do: {:error, :invalid_contact_payload}

  # ---------------------------------------------------------------------------
  # Company
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom company into a stable struct."
  @spec company(map()) :: {:ok, Company.t()} | {:error, term()}
  def company(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      workspace_id: Data.get(payload, "workspace_id"),
      name: Data.get(payload, "name"),
      company_id: Data.get(payload, "company_id"),
      remote_created_at: Data.get(payload, "remote_created_at"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      last_request_at: Data.get(payload, "last_request_at"),
      monthly_spend: Data.get(payload, "monthly_spend"),
      session_count: Data.get(payload, "session_count"),
      user_count: Data.get(payload, "user_count"),
      tags: Data.get(payload, "tags"),
      segments: Data.get(payload, "segments"),
      plan: Data.get(payload, "plan"),
      custom_attributes: Data.get(payload, "custom_attributes")
    }
    |> Data.compact()
    |> Company.new()
  end

  def company(_payload), do: {:error, :invalid_company_payload}

  # ---------------------------------------------------------------------------
  # Conversation
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom conversation into a stable struct."
  @spec conversation(map()) :: {:ok, Conversation.t()} | {:error, term()}
  def conversation(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      workspace_id: Data.get(payload, "workspace_id"),
      type: Data.get(payload, "type"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      waiting_since: Data.get(payload, "waiting_since"),
      snoozed_until: Data.get(payload, "snoozed_until"),
      title: Data.get(payload, "title"),
      state: Data.get(payload, "state"),
      open: Data.get(payload, "open"),
      read: Data.get(payload, "read"),
      priority: Data.get(payload, "priority"),
      source: Data.get(payload, "source"),
      contacts: Data.get(payload, "contacts"),
      teammates: Data.get(payload, "teammates"),
      admin_assignee_id: admin_assignee_id(payload),
      team_assignee_id: team_assignee_id(payload),
      tags: Data.get(payload, "tags"),
      conversation_parts: Data.get(payload, "conversation_parts"),
      statistics: Data.get(payload, "statistics"),
      custom_attributes: Data.get(payload, "custom_attributes")
    }
    |> Data.compact()
    |> Conversation.new()
  end

  def conversation(_payload), do: {:error, :invalid_conversation_payload}

  # ---------------------------------------------------------------------------
  # ConversationPart
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom conversation part into a stable struct."
  @spec conversation_part(map()) :: {:ok, ConversationPart.t()} | {:error, term()}
  def conversation_part(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      part_type: Data.get(payload, "part_type"),
      body: Data.get(payload, "body"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      notified_at: Data.get(payload, "notified_at"),
      assigned_to: Data.get(payload, "assigned_to"),
      author: Data.get(payload, "author"),
      attachments: Data.get(payload, "attachments", [])
    }
    |> Data.compact()
    |> ConversationPart.new()
  end

  def conversation_part(_payload), do: {:error, :invalid_conversation_part_payload}

  # ---------------------------------------------------------------------------
  # Admin
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom admin (teammate) into a stable struct."
  @spec admin(map()) :: {:ok, Admin.t()} | {:error, term()}
  def admin(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      name: Data.get(payload, "name"),
      email: Data.get(payload, "email"),
      job_title: Data.get(payload, "job_title"),
      away_mode_enabled: Data.get(payload, "away_mode_enabled"),
      away_mode_reassign: Data.get(payload, "away_mode_reassign"),
      has_inbox_seat: Data.get(payload, "has_inbox_seat"),
      team_ids: Data.get(payload, "team_ids", []),
      avatar: Data.get(payload, "avatar")
    }
    |> Data.compact()
    |> Admin.new()
  end

  def admin(_payload), do: {:error, :invalid_admin_payload}

  # ---------------------------------------------------------------------------
  # Team
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom team into a stable struct."
  @spec team(map()) :: {:ok, Team.t()} | {:error, term()}
  def team(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      name: Data.get(payload, "name"),
      admin_ids: Data.get(payload, "admin_ids", [])
    }
    |> Data.compact()
    |> Team.new()
  end

  def team(_payload), do: {:error, :invalid_team_payload}

  # ---------------------------------------------------------------------------
  # Tag
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom tag into a stable struct."
  @spec tag(map()) :: {:ok, Tag.t()} | {:error, term()}
  def tag(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      type: Data.get(payload, "type"),
      name: Data.get(payload, "name")
    }
    |> Data.compact()
    |> Tag.new()
  end

  def tag(_payload), do: {:error, :invalid_tag_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom pagination envelope into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    pages = Data.get(payload, "pages", %{}) || %{}

    %{
      next: Data.get(pages, "next"),
      page: Data.get(pages, "page"),
      per_page: Data.get(pages, "per_page"),
      total_pages: Data.get(pages, "total_pages"),
      total_count: Data.get(payload, "total_count")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Webhook event normalization
  # ---------------------------------------------------------------------------

  @doc "Normalizes an Intercom webhook notification payload into a signal map."
  @spec normalize_webhook_event(map()) :: {:ok, map()} | {:error, term()}
  def normalize_webhook_event(%{"topic" => topic, "data" => %{"item" => item}} = payload) do
    {:ok,
     %{
       topic: topic,
       delivery_id: Data.get(payload, "delivery_id"),
       delivery_attempt: Data.get(payload, "delivery_attempt"),
       created_at: Data.get(payload, "created_at"),
       item: item,
       app_id: Data.get(payload, "app_id"),
       self: Data.get(payload, "self")
     }
     |> Data.compact()}
  end

  def normalize_webhook_event(%{"topic" => topic} = payload) do
    {:ok,
     %{
       topic: topic,
       delivery_id: Data.get(payload, "delivery_id"),
       delivery_attempt: Data.get(payload, "delivery_attempt"),
       created_at: Data.get(payload, "created_at"),
       data: Data.get(payload, "data"),
       app_id: Data.get(payload, "app_id"),
       self: Data.get(payload, "self")
     }
     |> Data.compact()}
  end

  def normalize_webhook_event(_payload), do: {:error, :invalid_webhook_event_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp admin_assignee_id(payload) do
    case Data.get(payload, "admin_assignee_id") do
      nil -> extract_assignee_id(payload, "admin")
      id -> id
    end
  end

  defp team_assignee_id(payload) do
    case Data.get(payload, "team_assignee_id") do
      nil -> extract_assignee_id(payload, "team")
      id -> id
    end
  end

  defp extract_assignee_id(payload, type) do
    case Data.get(payload, "assignee") do
      %{"type" => ^type, "id" => id} -> id
      _other -> nil
    end
  end
end
