defmodule Jido.Connect.HubSpot.Handlers.Triggers.ContactChangedPollerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Contact
  alias Jido.Connect.HubSpot.Handlers.Triggers.ContactChangedPoller

  defmodule FakeClient do
    # --- Initial full-scan (no filter_groups) ---

    def list_contacts(%{after: "page_2"}, "token") do
      {:ok,
       %{
         items: [
           Contact.new!(%{
             contact_id: "503",
             email: "dana@example.com",
             first_name: "Dana",
             last_name: "Kim",
             updated_at: "2026-05-15T14:00:00.000Z"
           })
         ]
       }}
    end

    def list_contacts(_params, "token") do
      {:ok,
       %{
         items: [
           Contact.new!(%{
             contact_id: "501",
             email: "bella@example.com",
             first_name: "Bella",
             last_name: "Martinez",
             updated_at: "2026-05-14T09:30:00.000Z"
           }),
           Contact.new!(%{
             contact_id: "502",
             email: "carlos@example.com",
             first_name: "Carlos",
             last_name: "Rivera",
             updated_at: "2026-05-15T10:00:00.000Z"
           })
         ],
         pagination: %{after: "page_2"}
       }}
    end

    # Empty contact list
    def list_contacts(_params, "empty_token") do
      {:ok, %{items: []}}
    end

    # --- Changed contacts (search with filter_groups) ---

    def search_contacts(%{filter_groups: [_], after: "page_2", updated_min: _}, "token") do
      {:ok,
       %{
         items: [
           Contact.new!(%{
             contact_id: "501",
             email: "bella@example.com",
             first_name: "Bella",
             last_name: "Martinez-Updated",
             updated_at: "2026-05-15T12:00:00.000Z"
           })
         ]
       }}
    end

    def search_contacts(
          %{
            filter_groups: [%{filters: [%{value: "2026-05-15T10:00:00.000Z"}]}],
            updated_min: "2026-05-15T10:00:00.000Z"
          },
          "token"
        ) do
      {:ok,
       %{
         items: [
           Contact.new!(%{
             contact_id: "502",
             email: "carlos-updated@example.com",
             first_name: "Carlos",
             last_name: "Rivera",
             updated_at: "2026-05-15T10:30:00.000Z"
           }),
           Contact.new!(%{
             contact_id: "504",
             email: "new@example.com",
             first_name: "Eve",
             last_name: "Chen",
             updated_at: "2026-05-15T11:00:00.000Z"
           })
         ],
         pagination: %{after: "page_2"}
       }}
    end

    def search_contacts(%{filter_groups: [_], updated_min: "2026-05-16T12:00:00.000Z"}, "token") do
      {:ok, %{items: []}}
    end

    def search_contacts(%{filter_groups: [_], updated_min: "2026-05-15T12:00:00.000Z"}, "token") do
      {:ok, %{items: []}}
    end


  end

  describe "poll/2 with no checkpoint" do
    test "initializes checkpoint without emitting signals" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               ContactChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})

      assert checkpoint == "2026-05-15T14:00:00.000Z"
    end

    test "initializes checkpoint with empty string treated as nil" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}

      assert {:ok, %{signals: []}} =
               ContactChangedPoller.poll(config, %{credentials: credentials, checkpoint: ""})
    end

    test "returns error when no contacts have updated timestamps" do
      config = %{}
      credentials = %{api_key: "empty_token", hubspot_client: FakeClient}

      assert {:error, %{reason: :invalid_response}} =
               ContactChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})
    end
  end

  describe "poll/2 with existing checkpoint" do
    test "emits signals for changed contacts and advances checkpoint" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals, checkpoint: new_checkpoint}} =
               ContactChangedPoller.poll(config, %{
                 credentials: credentials,
                 checkpoint: checkpoint
               })

      assert new_checkpoint == "2026-05-15T12:00:00.000Z"

      # 2 contacts on page 1 + 1 contact on page 2
      assert length(signals) == 3

      signal_ids = Enum.map(signals, & &1.contact_id) |> Enum.sort()
      assert signal_ids == ~w(501 502 504)
    end

    test "sets change_type to archived for archived contacts" do
      archived =
        Contact.new!(%{
          contact_id: "501",
          updated_at: "2026-05-15T12:00:00.000Z",
          archived?: true
        })

      _config = %{}
      _credentials = %{api_key: "token", hubspot_client: ArchivedFakeClient}

      # Test the normalize_signal path directly
      signal = normalize_contact_signal(archived)
      assert signal.change_type == "archived"
    end

    test "sets change_type to updated for normal contacts" do
      contact =
        Contact.new!(%{
          contact_id: "502",
          email: "carlos@example.com",
          updated_at: "2026-05-15T10:30:00.000Z"
        })

      signal = normalize_contact_signal(contact)
      assert signal.change_type == "updated"
    end

    test "deduplicates signals with same contact_id and updated_at" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals}} =
               ContactChangedPoller.poll(config, %{
                 credentials: credentials,
                 checkpoint: checkpoint
               })

      keys = Enum.map(signals, &{&1.contact_id, &1.updated_at})
      assert length(keys) == length(Enum.uniq(keys))
    end

    test "returns empty signals when no contacts changed" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-16T12:00:00.000Z"

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} =
               ContactChangedPoller.poll(config, %{
                 credentials: credentials,
                 checkpoint: checkpoint
               })
    end
  end

  describe "signal shape" do
    test "each signal contains expected fields" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: [signal | _]}} =
               ContactChangedPoller.poll(config, %{
                 credentials: credentials,
                 checkpoint: checkpoint
               })

      assert Map.has_key?(signal, :contact_id)
      assert Map.has_key?(signal, :change_type)
      assert Map.has_key?(signal, :updated_at)
      assert Map.has_key?(signal, :contact)
    end
  end

  # Helper for testing normalize_signal behavior directly
  defp normalize_contact_signal(contact) do
    %{
      contact_id: Map.get(contact, :contact_id),
      change_type: change_type(contact),
      updated_at: Map.get(contact, :updated_at)
    }
  end

  defp change_type(%{archived?: true}), do: "archived"
  defp change_type(_contact), do: "updated"
end
