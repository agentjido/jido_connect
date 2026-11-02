defmodule Jido.Connect.Google.Meet.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Meet action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Meet, [
      action("google.meet.space.create", :personal_data, :write, :required_for_ai),
      action("google.meet.space.get", :personal_data, :read, :none),
      action("google.meet.conference_record.list", :personal_data, :read, :none),
      action("google.meet.conference_record.get", :personal_data, :read, :none),
      action("google.meet.recording.list", :personal_data, :read, :none),
      action("google.meet.recording.get", :personal_data, :read, :none),
      action("google.meet.transcript.list", :personal_data, :read, :none,
        text_includes: ["metadata"]
      ),
      action("google.meet.transcript.get", :personal_data, :read, :none,
        text_includes: ["metadata"]
      ),
      action("google.meet.transcript.entry.list", :workspace_content, :read, :none,
        text_includes: ["transcript text"]
      )
    ])
  end

  defp action(id, classification, risk, confirmation, opts \\ []) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
