defmodule Jido.Connect.Google.Forms.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Forms action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Forms,
      [
        action("google.forms.form.get", :workspace_content, :read, :none,
          text_includes: ["form"]
        ),
        action("google.forms.form.create", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["form"]
        ),
        action("google.forms.form.batch_update", :workspace_content, :destructive, :always,
          text_includes: ["form"]
        ),
        action("google.forms.responses.list", :personal_data, :read, :none,
          text_includes: ["response"]
        ),
        action("google.forms.responses.get", :personal_data, :read, :none,
          text_includes: ["response"]
        ),
        action("google.forms.watch.create", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["watch"]
        ),
        action("google.forms.watch.renew", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["watch"]
        ),
        action("google.forms.watch.delete", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["watch"]
        )
      ],
      [
        trigger("google.forms.response.submitted", :personal_data, text_includes: ["response"])
      ]
    )
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

  defp trigger(id, classification, opts) do
    %{
      id: id,
      classification: classification,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
