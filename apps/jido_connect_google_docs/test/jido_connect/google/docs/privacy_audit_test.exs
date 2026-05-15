defmodule Jido.Connect.Google.Docs.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Docs action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Docs, [
      action("google.docs.document.get", :workspace_content, :read, :none,
        text_includes: ["document"]
      ),
      action("google.docs.document.create", :workspace_metadata, :write, :required_for_ai,
        text_includes: ["document"]
      )
    ])
  end

  defp action(id, classification, risk, confirmation, opts) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
