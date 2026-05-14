defmodule Jido.Connect.Google.Drive.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Drive action and trigger privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Drive,
      [
        action("google.drive.files.list", :workspace_metadata, :read, :none),
        action("google.drive.file.get", :workspace_metadata, :read, :none,
          text_includes: ["metadata"]
        ),
        action("google.drive.file.create", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["metadata"]
        ),
        action("google.drive.folder.create", :workspace_metadata, :write, :required_for_ai),
        action("google.drive.file.copy", :workspace_metadata, :write, :required_for_ai),
        action("google.drive.file.update", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["metadata"]
        ),
        action("google.drive.file.export", :workspace_content, :read, :none,
          text_includes: ["file content"]
        ),
        action("google.drive.file.download", :workspace_content, :read, :none,
          text_includes: ["file content"]
        ),
        action("google.drive.file.delete", :workspace_metadata, :destructive, :always),
        action("google.drive.permissions.list", :personal_data, :read, :none,
          text_includes: ["permissions"]
        ),
        action("google.drive.permission.create", :personal_data, :external_write, :always,
          text_includes: ["permission"]
        ),
        action("google.drive.changes.watch", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["push", "notification"]
        ),
        action("google.drive.file.watch", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["push", "notification"]
        ),
        action("google.drive.channel.stop", :workspace_metadata, :write, :required_for_ai,
          text_includes: ["push", "notification"]
        )
      ],
      [
        trigger("google.drive.file.changed", :workspace_metadata,
          text_includes: ["file", "changed"]
        ),
        trigger("google.drive.file.changed.push", :workspace_metadata,
          text_includes: ["push", "notification"]
        )
      ]
    )
  end

  test "normalizes Drive file metadata without content bytes" do
    {:ok, file} =
      Normalizer.file(%{
        "id" => "file123",
        "name" => "Budget.pdf",
        "mimeType" => "application/pdf",
        "content" => "raw-bytes",
        "contentBytes" => "raw-bytes",
        "webContentLink" => "https://drive.example/download"
      })

    file = Map.from_struct(file)

    refute Map.has_key?(file, :content)
    refute Map.has_key?(file, :content_bytes)
    refute inspect(file) =~ "raw-bytes"
    assert file.web_content_link == "https://drive.example/download"
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

  defp trigger(id, classification, opts) do
    %{
      id: id,
      classification: classification,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
