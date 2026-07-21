defmodule Jido.Connect.Google.Drive.CollectionChangesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.CollectionChanges
  alias Jido.Connect.Google.Drive.Handlers.Actions.ListCollectionChanges
  alias Jido.Connect.Google.Drive.Handlers.Actions.WatchCollection
  alias Jido.Connect.Google.Drive.Handlers.Triggers.CollectionChangesPoller

  defmodule FakeDriveClient do
    @collection_lookup_fields "id,mimeType,driveId"

    def get_file(
          %{
            file_id: "folder123",
            fields: @collection_lookup_fields,
            supports_all_drives: true
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "folder123",
         name: "Reports",
         mime_type: "application/vnd.google-apps.folder"
       })}
    end

    def get_file(
          %{
            file_id: "not-a-folder",
            fields: @collection_lookup_fields,
            supports_all_drives: true
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "not-a-folder",
         name: "Document",
         mime_type: "application/pdf"
       })}
    end

    def get_file(
          %{
            file_id: "shared-folder",
            fields: @collection_lookup_fields,
            supports_all_drives: true
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "shared-folder",
         name: "Shared reports",
         mime_type: "application/vnd.google-apps.folder",
         drive_id: "drive123"
       })}
    end

    def get_start_page_token(%{supports_all_drives: false}, "token") do
      {:ok, %{start_page_token: "my-drive-start-token"}}
    end

    def get_start_page_token(
          %{drive_id: "drive123", supports_all_drives: true},
          "token"
        ) do
      {:ok, %{start_page_token: "shared-start-token"}}
    end

    def watch_changes(
          %{
            page_token: "shared-start-token",
            drive_id: "drive123",
            include_items_from_all_drives: true,
            restrict_to_my_drive: false,
            supports_all_drives: true,
            channel_id: "channel-123",
            address: "https://example.com/drive/webhook"
          },
          "token"
        ) do
      {:ok,
       Drive.Channel.new!(%{
         channel_id: "channel-123",
         resource_id: "resource-123",
         resource_uri: "https://www.googleapis.com/drive/v3/changes"
       })}
    end

    def list_changes(
          %{
            page_token: "move-token",
            page_size: 250,
            spaces: "drive",
            include_items_from_all_drives: false,
            include_removed: true,
            restrict_to_my_drive: false,
            supports_all_drives: false
          } = params,
          "token"
        ) do
      refute_custom_fields!(params)

      {:ok,
       %{
         changes: [
           change("inside-file", ["folder123"], "2026-07-20T12:00:00Z"),
           change("moved-file", ["other-folder"], "2026-07-20T12:01:00Z"),
           Drive.Change.new!(%{
             file_id: "removed-file",
             removed?: true,
             time: "2026-07-20T12:02:00Z",
             change_type: "file"
           }),
           Drive.Change.new!(%{
             drive_id: "drive123",
             removed?: false,
             time: "2026-07-20T12:03:00Z",
             change_type: "drive"
           })
         ],
         new_start_page_token: "next-token"
       }}
    end

    def list_changes(%{page_token: "preferred-checkpoint"}, "token") do
      {:ok, %{changes: [], new_start_page_token: "preferred-next-token"}}
    end

    def list_changes(%{page_token: "missing-next-checkpoint"}, "token") do
      {:ok, %{changes: []}}
    end

    def list_changes(
          %{
            page_token: "shared-page-token",
            drive_id: "drive123",
            include_items_from_all_drives: true,
            restrict_to_my_drive: false,
            supports_all_drives: true
          } = params,
          "token"
        ) do
      refute_custom_fields!(params)
      {:ok, %{changes: [], new_start_page_token: "shared-next-token"}}
    end

    defp change(file_id, parents, time) do
      Drive.Change.new!(%{
        file_id: file_id,
        removed?: false,
        time: time,
        change_type: "file",
        file:
          Drive.File.new!(%{
            file_id: file_id,
            name: "Document",
            mime_type: "application/pdf",
            parents: parents
          })
      })
    end

    defp refute_custom_fields!(params) do
      if Map.has_key?(params, :fields) do
        raise "collection changes must use the required Drive field mask"
      end
    end
  end

  test "emits current non-members so hosts can remove files moved out of a collection" do
    assert {:ok, %{signals: signals, checkpoint: "next-token"}} =
             CollectionChanges.list(
               FakeDriveClient,
               %{
                 collection_id: "folder123",
                 page_size: 250,
                 fields: "changes(fileId)",
                 spaces: "appDataFolder",
                 drive_id: "wrong-drive",
                 include_items_from_all_drives: true,
                 include_removed: false,
                 restrict_to_my_drive: true,
                 supports_all_drives: true
               },
               "move-token",
               "token"
             )

    assert %{collection_match: "yes", provider_record_id: "inside-file"} =
             Enum.find(signals, &(&1.provider_record_id == "inside-file"))

    assert %{
             collection_match: "no",
             provider_record_id: "moved-file",
             record: %{parents: ["other-folder"]}
           } = Enum.find(signals, &(&1.provider_record_id == "moved-file"))

    assert %{collection_match: "unknown", provider_record_id: "removed-file"} =
             Enum.find(signals, &(&1.provider_record_id == "removed-file"))

    refute Enum.any?(signals, &is_nil(&1.provider_record_id))
  end

  test "resolves a shared-drive collection before it creates the change watch" do
    assert {:ok,
            %{
              checkpoint: "shared-start-token",
              collection_id: "shared-folder",
              drive_id: "drive123"
            }} =
             WatchCollection.run(
               %{
                 collection_id: " shared-folder ",
                 channel_id: "channel-123",
                 address: "https://example.com/drive/webhook"
               },
               %{
                 credentials: %{
                   access_token: "token",
                   google_drive_client: FakeDriveClient
                 }
               }
             )
  end

  test "uses the resolved shared-drive change log when it lists changes" do
    assert {:ok, %{signals: [], checkpoint: "shared-next-token"}} =
             CollectionChanges.list(
               FakeDriveClient,
               %{collection_id: "shared-folder"},
               "shared-page-token",
               "token"
             )
  end

  test "rejects missing and blank collection IDs" do
    for config <- [%{}, %{collection_id: nil}, %{collection_id: " \t "}] do
      assert {:error,
              %Error.ValidationError{
                reason: :invalid_drive_collection,
                details: %{field: :collection_id}
              }} =
               CollectionChanges.init_checkpoint(FakeDriveClient, config, "token")
    end
  end

  test "rejects IDs that do not identify Drive folders" do
    assert {:error,
            %Error.ValidationError{
              reason: :invalid_drive_collection,
              details: %{
                field: :collection_id,
                value: "not-a-folder",
                mime_type: "application/pdf"
              }
            }} =
             CollectionChanges.init_checkpoint(
               FakeDriveClient,
               %{collection_id: "not-a-folder"},
               "token"
             )
  end

  test "rejects invalid page sizes before calling Drive" do
    for page_size <- [0, 1001, "100"] do
      assert {:error,
              %Error.ValidationError{
                reason: :invalid_drive_collection,
                details: %{field: :page_size, value: ^page_size, min: 1, max: 1000}
              }} =
               CollectionChanges.init_checkpoint(
                 FakeDriveClient,
                 %{collection_id: "folder123", page_size: page_size},
                 "token"
               )
    end
  end

  test "rejects terminal pages that cannot advance the checkpoint" do
    assert {:error,
            %Error.ProviderError{
              reason: :invalid_response,
              details: %{field: :new_start_page_token}
            }} =
             CollectionChanges.list(
               FakeDriveClient,
               %{collection_id: "folder123"},
               "missing-next-checkpoint",
               "token"
             )
  end

  test "uses checkpoint before its deprecated cursor alias" do
    assert {:ok, %{checkpoint: "preferred-next-token"}} =
             ListCollectionChanges.run(
               %{
                 collection_id: "folder123",
                 checkpoint: " preferred-checkpoint ",
                 cursor: " "
               },
               %{
                 credentials: %{
                   access_token: "token",
                   google_drive_client: FakeDriveClient
                 }
               }
             )
  end

  test "treats a blank poll checkpoint as uninitialized" do
    assert {:ok, %{signals: [], checkpoint: "my-drive-start-token"}} =
             CollectionChangesPoller.poll(
               %{collection_id: "folder123"},
               %{
                 checkpoint: " \t ",
                 credentials: %{
                   access_token: "token",
                   google_drive_client: FakeDriveClient
                 }
               }
             )
  end

  test "collection actions require IDs and do not expose unsafe field masks" do
    spec = Drive.integration()

    watch = Enum.find(spec.actions, &(&1.id == "google.drive.collection.watch"))
    list = Enum.find(spec.actions, &(&1.id == "google.drive.collection.changes.list"))
    poll = Enum.find(spec.triggers, &(&1.id == "google.drive.collection.changes"))

    assert Enum.find(watch.input, &(&1.name == :collection_id)).required?
    assert Enum.find(list.input, &(&1.name == :collection_id)).required?

    derived_fields = [
      :fields,
      :spaces,
      :drive_id,
      :include_corpus_removals,
      :include_items_from_all_drives,
      :include_removed,
      :restrict_to_my_drive,
      :include_permissions_for_view,
      :include_labels,
      :supports_all_drives
    ]

    for field <- derived_fields do
      refute Enum.any?(watch.input, &(&1.name == field))
      refute Enum.any?(list.input, &(&1.name == field))
      refute Enum.any?(poll.config, &(&1.name == field))
    end
  end
end
