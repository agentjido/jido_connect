defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateNoteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Handlers.Actions.CreateNote
  alias Jido.Connect.HubSpot.Note

  describe "run/2" do
    test "returns note on success" do
      note =
        Note.new!(%{
          note_id: "601",
          body: "Had a great discovery call.",
          contact_ids: ["501"],
          deal_ids: ["301"]
        })

      MockClient.stub(create_note: {:ok, note})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{note: result}} =
               CreateNote.run(
                 %{body: "Had a great discovery call.", contact_ids: ["501"], deal_ids: ["301"]},
                 %{credentials: credentials}
               )

      assert result.note_id == "601"
      assert result.body == "Had a great discovery call."
      assert result.contact_ids == ["501"]
      assert result.deal_ids == ["301"]
    end

    test "returns note without associations" do
      note = Note.new!(%{note_id: "602", body: "Standalone note."})
      MockClient.stub(create_note: {:ok, note})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{note: result}} =
               CreateNote.run(%{body: "Standalone note."}, %{credentials: credentials})

      assert result.note_id == "602"
      assert result.body == "Standalone note."
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Validation error"}}

      MockClient.stub(create_note: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateNote.run(%{body: ""}, %{credentials: credentials})
    end
  end
end
