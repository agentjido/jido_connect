ExUnit.start()

defmodule Jido.Connect.Intercom.MockClient do
  @moduledoc false

  alias Jido.Connect.Error

  # ---------------------------------------------------------------------------
  # Contacts
  # ---------------------------------------------------------------------------

  def list_contacts("token", opts) do
    per_page = Keyword.get(opts, :per_page)

    contacts =
      if per_page == 1 do
        [contact_payload("661240", "Alice Nakamura", "alice@example.com")]
      else
        [
          contact_payload("661240", "Alice Nakamura", "alice@example.com"),
          contact_payload("661241", "Bob Martinez", "bob@example.com")
        ]
      end

    pagination = %{
      next: if(per_page == 1, do: %{"page" => 2, "per_page" => 1}, else: nil),
      page: 1,
      per_page: per_page || 20,
      total_count: 2
    }

    {:ok, %{items: contacts, pagination: pagination}}
  end

  def list_contacts("error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  def search_contacts("email:alice@example.com", "token", _opts) do
    {:ok,
     %{
       items: [contact_payload("661240", "Alice Nakamura", "alice@example.com")],
       pagination: nil,
       total_count: 1
     }}
  end

  def search_contacts(_query, "token", _opts) do
    {:ok, %{items: [], pagination: nil, total_count: 0}}
  end

  def get_contact("661240", "token", _opts) do
    {:ok, contact_payload("661240", "Alice Nakamura", "alice@example.com")}
  end

  def get_contact("unknown", "token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :http_error,
       status: 404,
       details: %{message: "Not found", body: %{"type" => "error.list"}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Conversations
  # ---------------------------------------------------------------------------

  def list_conversations("token", opts) do
    per_page = Keyword.get(opts, :per_page)

    conversations =
      if per_page == 1 do
        [conversation_payload("401", "open", "Need help with API integration")]
      else
        [
          conversation_payload("401", "open", "Need help with API integration"),
          conversation_payload("402", "closed", nil)
        ]
      end

    pagination = %{
      next: if(per_page == 1, do: %{"page" => 2, "per_page" => 1}, else: nil),
      page: 1,
      per_page: per_page || 20,
      total_count: 2
    }

    {:ok, %{items: conversations, pagination: pagination}}
  end

  def list_conversations("rate_limited_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :rate_limited,
       status: 429,
       details: %{message: "Rate limit exceeded", body: %{"type" => "error.list"}}
     }}
  end

  def search_conversations("open:true", "token", _opts) do
    {:ok,
     %{
       items: [conversation_payload("401", "open", "Need help with API integration")],
       pagination: nil,
       total_count: 1
     }}
  end

  def search_conversations(_query, "token", _opts) do
    {:ok, %{items: [], pagination: nil, total_count: 0}}
  end

  def get_conversation("401", "token", _opts) do
    {:ok, conversation_payload("401", "open", "Need help with API integration")}
  end

  def get_conversation("unknown", "token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :http_error,
       status: 404,
       details: %{message: "Not found", body: %{"type" => "error.list"}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Admins
  # ---------------------------------------------------------------------------

  def list_admins("token", _opts) do
    {:ok,
     %{
       items: [
         admin_payload("991", "Carol Chen", "carol@example.com"),
         admin_payload("992", "Dave Park", nil)
       ],
       pagination: %{next: nil, page: 1, per_page: 20, total_count: 2}
     }}
  end

  # ---------------------------------------------------------------------------
  # Teams
  # ---------------------------------------------------------------------------

  def list_teams("token", _opts) do
    {:ok,
     %{
       items: [
         team_payload("team-100", "Support", ["991", "992"]),
         team_payload("team-200", "Engineering", [])
       ],
       pagination: %{next: nil, page: 1, per_page: 20, total_count: 2}
     }}
  end

  # ---------------------------------------------------------------------------
  # Contact write
  # ---------------------------------------------------------------------------

  def create_contact(%{email: "new@example.com"} = _attrs, "token", _opts) do
    {:ok,
     %{
       id: "661300",
       name: "New User",
       email: "new@example.com",
       role: "user",
       created_at: 1_718_500_000,
       updated_at: 1_718_500_000
     }}
  end

  def create_contact(_attrs, "token", _opts) do
    {:ok,
     %{
       id: "661301",
       name: "Created Contact",
       email: "created@example.com",
       role: "user",
       created_at: 1_718_500_000,
       updated_at: 1_718_500_000
     }}
  end

  def create_contact(_attrs, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  def update_contact("661240", _attrs, "token", _opts) do
    {:ok,
     %{
       id: "661240",
       name: "Alice Updated",
       email: "alice-updated@example.com",
       role: "user",
       updated_at: 1_718_506_000
     }}
  end

  def update_contact(_contact_id, _attrs, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Conversation write
  # ---------------------------------------------------------------------------

  def reply_conversation("401", _attrs, "token", _opts) do
    {:ok,
     %{
       id: "part-100",
       part_type: "comment",
       body: "<p>Reply text</p>",
       created_at: 1_718_506_000
     }}
  end

  def reply_conversation(_conversation_id, _attrs, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  def add_note("401", _attrs, "token", _opts) do
    {:ok,
     %{
       id: "part-200",
       part_type: "note",
       body: "<p>Internal note</p>",
       created_at: 1_718_506_000
     }}
  end

  def add_note(_conversation_id, _attrs, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  def assign_conversation("401", %{admin_id: admin_id} = _attrs, "token", _opts)
      when is_binary(admin_id) do
    {:ok,
     %{
       id: "part-300",
       part_type: "assignment",
       assigned_to: %{type: "admin", id: admin_id},
       created_at: 1_718_506_000
     }}
  end

  def assign_conversation(
        "401",
        %{assignee_id: %{type: "team", id: team_id}} = _attrs,
        "token",
        _opts
      ) do
    {:ok,
     %{
       id: "part-301",
       part_type: "assignment",
       assigned_to: %{type: "team", id: team_id},
       created_at: 1_718_506_000
     }}
  end

  def assign_conversation(_conversation_id, _attrs, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Tag write
  # ---------------------------------------------------------------------------

  def tag_contact("vip", ["661240"], "token", _opts) do
    {:ok,
     %{
       id: "tag-100",
       name: "vip",
       type: "tag",
       applied_to: %{type: "contact", contacts: [%{id: "661240"}]}
     }}
  end

  def tag_contact(_name, _contact_ids, "token", _opts) do
    {:ok,
     %{
       id: "tag-101",
       name: "test-tag",
       type: "tag",
       applied_to: %{type: "contact", contacts: []}
     }}
  end

  def tag_contact(_name, _contact_ids, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  def untag_contact("tag-100", ["661240"], "token", _opts) do
    {:ok,
     %{
       id: "tag-100",
       name: "vip",
       type: "tag",
       applied_to: %{type: "contact", contacts: [%{id: "661240"}]}
     }}
  end

  def untag_contact(_tag_id, _contact_ids, "error_token", _opts) do
    {:error,
     %Error.ProviderError{
       message: "Intercom API request failed",
       provider: :intercom,
       reason: :unauthorized,
       status: 401,
       details: %{message: "Unauthorized", body: %{"type" => "error.list"}}
     }}
  end

  # ---------------------------------------------------------------------------
  # Client resolution helpers
  # ---------------------------------------------------------------------------

  def credential_token(%{api_key: key}), do: key
  def credential_token(%{access_token: token}), do: token

  # ---------------------------------------------------------------------------
  # Payload helpers
  # ---------------------------------------------------------------------------

  defp contact_payload(id, name, email) do
    %{
      id: id,
      name: name,
      email: email,
      role: "user",
      has_hard_bounced: false,
      marked_email_as_spam: false,
      unsubscribed_from_emails: false,
      created_at: 1_717_804_800,
      updated_at: 1_718_496_000
    }
  end

  defp conversation_payload(id, state, title) do
    %{
      id: id,
      state: state,
      open: state == "open",
      read: true,
      title: title,
      priority: "not_priority",
      created_at: 1_718_496_000,
      updated_at: 1_718_496_600
    }
  end

  defp admin_payload(id, name, email) do
    %{
      id: id,
      type: "admin",
      name: name,
      email: email,
      has_inbox_seat: true,
      team_ids: []
    }
  end

  defp team_payload(id, name, admin_ids) do
    %{
      id: id,
      type: "team",
      name: name,
      admin_ids: admin_ids
    }
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
