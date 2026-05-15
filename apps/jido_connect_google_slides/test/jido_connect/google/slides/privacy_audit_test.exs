defmodule Jido.Connect.Google.Slides.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Slides action privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(Slides, [
      action("google.slides.presentation.get", :workspace_content, :read, :none,
        text_includes: ["presentation"]
      ),
      action("google.slides.presentation.create", :workspace_metadata, :write, :required_for_ai,
        text_includes: ["presentation"]
      ),
      action(
        "google.slides.presentation.batch_update",
        :workspace_content,
        :write,
        :required_for_ai,
        text_includes: ["presentation"]
      ),
      action("google.slides.presentation.page.get_thumbnail", :workspace_content, :read, :none,
        text_includes: ["thumbnail"]
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
