defmodule Jido.Connect.Google.Forms.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Forms action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Forms, [
      action("google.forms.form.get", :workspace_content, :read, :none, text_includes: ["form"]),
      action("google.forms.form.create", :workspace_metadata, :write, :required_for_ai,
        text_includes: ["form"]
      ),
      action("google.forms.form.batch_update", :workspace_content, :destructive, :always,
        text_includes: ["form"]
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
