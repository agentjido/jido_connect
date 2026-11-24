defmodule Jido.Connect.Google.Drive.ChangeFeedTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.TestSupport.LiveSmoke

  # The prepared watch folder and the objects the live tests created and
  # removed again while they recorded the fixtures.
  @watch_folder "1WBlaIDsYb-vmynE8OnECx6l7vunVL0So"
  @added "16G0zkY3iWCmTdJGqvj3OyCTAPqU0fgU9"
  @subfolder "1ZZhnM_eWX4wvZnoTS-LG1q5JiuG_6Wx1"
  @nested "1A36l7QZp2EifPB3FQAMdg1r9SjUYbw3o"
  @trashed "1wuBTBgKsmgGOL06HHHWxvFQgS16PuL-k"
  @removed "169L8tikOCrVn8N3aHI4ZPRnn0xY0Rr9C"
  @shared_drive "0ANlr4uaAlMbAUk9PVA"

  # The ID of the recorded lookup of a missing file.
  @missing "1JclLiveSmokeMissingFile000000000"

  # Drive's page tokens are opaque; the host passes its stored one back.
  @checkpoint "stored-checkpoint"

  # The projection of the folder lookup the recordings were made with. Drive
  # returns only the requested fields.
  @folder_lookup_fields "id,name,mimeType,driveId"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "https://drive.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_drive, :google_drive_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "the google.drive.file.changed description does not claim creations" do
    trigger = Enum.find(Drive.integration().triggers, &(&1.id == "google.drive.file.changed"))

    refute trigger.description =~ ~r/creat/i
  end

  describe "google.drive.collection.changes" do
    test "matches added direct children and not a file inside a subfolder" do
      expect_folder_lookup("collection_changes_added")
      expect_change_page("collection_changes_added.2", @checkpoint)

      assert {:ok, %{signals: signals, checkpoint: "105"}} =
               poll("google.drive.collection.changes", %{collection_id: @watch_folder})

      assert %{
               collection_match: "yes",
               change_type: "updated",
               removed?: false,
               record: %{created_at: "2026-11-02T09:46:00.962Z", parents: [@watch_folder]}
             } = record_signal(signals, @added)

      assert %{
               collection_match: "yes",
               record: %{
                 mime_type: "application/vnd.google-apps.folder",
                 parents: [@watch_folder]
               }
             } = record_signal(signals, @subfolder)

      assert %{collection_match: "no", record: %{parents: [@subfolder]}} =
               record_signal(signals, @nested)
    end

    test "matches a child moved to the trash and cannot place a removed one" do
      expect_folder_lookup("collection_changes_trashed")
      expect_change_page("collection_changes_trashed.2", @checkpoint)
      expect_change_page("collection_changes_trashed.3", "112")

      assert {:ok, %{signals: [trashed, removed], checkpoint: "113"}} =
               poll("google.drive.collection.changes", %{collection_id: @watch_folder})

      assert %{
               provider_record_id: @trashed,
               collection_match: "yes",
               change_type: "updated",
               removed?: false,
               record: %{trashed?: true, parents: [@watch_folder]}
             } = trashed

      assert removed == %{
               collection_id: @watch_folder,
               collection_match: "unknown",
               provider: "google_drive",
               provider_record_id: @removed,
               change_type: "deleted",
               removed?: true,
               changed_at: "2026-11-02T09:46:54.413Z"
             }
    end

    # The next two tests watch an object of the recordings in place of the
    # watch folder. The folder lookup answers with the recorded lookup of the
    # watch folder, its `id` replaced by the stand-in's ID.

    test "matches a change to the watched folder itself" do
      expect_folder_lookup("collection_changes_added", @subfolder)
      expect_change_page("collection_changes_added.2", @checkpoint)

      assert {:ok, %{signals: signals}} =
               poll("google.drive.collection.changes", %{collection_id: @subfolder})

      assert %{collection_match: "yes", record: %{parents: [@watch_folder]}} =
               record_signal(signals, @subfolder)

      assert %{collection_match: "yes"} = record_signal(signals, @nested)
      assert %{collection_match: "no"} = record_signal(signals, @added)
    end

    # A removal names only the file ID, so the recorded removal of a file
    # stands in for a removal of the watched folder that Drive records between
    # the folder lookup and the change read.
    test "cannot place a removal of the watched folder itself" do
      expect_folder_lookup("collection_changes_trashed", @removed)
      expect_change_page("collection_changes_trashed.2", @checkpoint)
      expect_change_page("collection_changes_trashed.3", "112")

      assert {:ok, %{signals: signals}} =
               poll("google.drive.collection.changes", %{collection_id: @removed})

      assert %{collection_match: "unknown", change_type: "deleted", removed?: true} =
               record_signal(signals, @removed)
    end

    # Drive answers the lookup of a deleted folder, or of one the user can no
    # longer see, as it answered the recorded lookup of a missing file.
    test "fails without checkpoint_reset once the watched folder is gone" do
      for checkpoint <- [@checkpoint, nil] do
        Req.Test.expect(__MODULE__, fn conn ->
          assert conn.request_path == "/v3/files/#{@missing}"

          conn
          |> Plug.Conn.put_status(404)
          |> Req.Test.json(LiveSmoke.fixture!(:google_drive, "file_get_not_found"))
        end)

        assert {:error,
                %Connect.Error.ProviderError{reason: :http_error, status: 404, details: details}} =
                 poll("google.drive.collection.changes", %{collection_id: @missing}, checkpoint)

        refute Map.has_key?(details, :checkpoint_reset)
      end
    end
  end

  describe "google.drive.file.changed" do
    test "returns a removal without file metadata as file_id, removed and time" do
      expect_change_page("file_changed_removed", @checkpoint, %{
        "includeItemsFromAllDrives" => "false"
      })

      assert {:ok, %{signals: signals, checkpoint: "105"}} =
               poll("google.drive.file.changed", %{})

      assert file_signal(signals, @added) == %{
               file_id: @added,
               removed: true,
               time: "2026-11-02T09:46:01.724Z",
               change_type: "file"
             }
    end

    test "keeps a trash-only update, a removal and a drive-level change apart" do
      expect_change_page("file_changed_mixed", @checkpoint, %{
        "includeItemsFromAllDrives" => "true",
        "supportsAllDrives" => "true"
      })

      assert {:ok, %{signals: [trashed, removed, drive_change], checkpoint: "113"}} =
               poll("google.drive.file.changed", %{
                 include_items_from_all_drives: true,
                 supports_all_drives: true
               })

      assert %{
               file_id: @trashed,
               removed: false,
               change_type: "file",
               file: %{file_id: @trashed, trashed?: true, parents: [@watch_folder]}
             } = trashed

      assert removed == %{
               file_id: @removed,
               removed: true,
               time: "2026-11-02T09:46:54.413Z",
               change_type: "file"
             }

      assert drive_change == %{
               drive_id: @shared_drive,
               removed: false,
               time: "2026-11-02T09:46:55.839Z",
               change_type: "drive"
             }
    end

    test "returns a file's metadata without a nested file key" do
      expect_change_page("collection_changes_added.2", @checkpoint)

      %{"file" => %{"owners" => owners}} =
        recorded_change("collection_changes_added.2", @added)

      assert {:ok, %{signals: signals}} = poll("google.drive.file.changed", %{})
      assert %{file: file} = file_signal(signals, @added)

      refute Map.has_key?(file, :file)
      assert file.owners == owners
      assert file.permissions == []
    end

    # No recording holds a file's `permissions`; the live polls did not ask
    # for them. The page is the recorded one with the recorded owner added as
    # a permission in the fields of `Fields.permission_metadata/0`. Drive
    # names a user's permission by the user's `permissionId`.
    test "returns a file's permissions as plain maps that encode as JSON" do
      page =
        :google_drive
        |> LiveSmoke.fixture!("collection_changes_added.2")
        |> Map.update!("changes", fn changes ->
          Enum.map(changes, fn
            %{"fileId" => @added, "file" => %{"owners" => [owner]}} = change ->
              put_in(change, ["file", "permissions"], [owner_permission(owner)])

            change ->
              change
          end)
        end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_params["pageToken"] == @checkpoint
        Req.Test.json(conn, page)
      end)

      assert {:ok, %{signals: signals}} = poll("google.drive.file.changed", %{})
      assert %{file: %{permissions: [permission]}} = file_signal(signals, @added)

      refute is_struct(permission)

      assert %{
               permission_id: "permissionId-1",
               type: "user",
               role: "owner",
               email_address: "person-1@example.com",
               display_name: "Person 1"
             } = permission

      assert {:ok, _json} = Jason.encode(signals)
    end
  end

  # Both recordings read the change log from a checkpoint taken before the
  # file was created. Drive merged the file's changes in each range into one:
  # the first poll, before the deletion, read its creation; the second, after
  # it, read the removal with the creation's `time`.
  describe "dedupe keys of an update and a removal with the same time" do
    test "differ for google.drive.file.changed across polls" do
      expect_change_page("collection_changes_added.2", @checkpoint)
      expect_change_page("file_changed_removed", @checkpoint)

      assert {:ok, %{signals: before_deletion}} = poll("google.drive.file.changed", %{})
      assert {:ok, %{signals: after_deletion}} = poll("google.drive.file.changed", %{})

      assert %{removed: false, time: time} = update = file_signal(before_deletion, @added)
      assert %{removed: true, time: ^time} = removal = file_signal(after_deletion, @added)

      refute dedupe_key("google.drive.file.changed", update) ==
               dedupe_key("google.drive.file.changed", removal)
    end

    # The two recorded pages as one poll: the first page's
    # `newStartPageToken` stands in as its `nextPageToken`.
    test "differ for google.drive.file.changed within one poll" do
      {next_page_token, first_page} =
        :google_drive
        |> LiveSmoke.fixture!("collection_changes_added.2")
        |> Map.pop!("newStartPageToken")

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_params["pageToken"] == @checkpoint
        Req.Test.json(conn, Map.put(first_page, "nextPageToken", next_page_token))
      end)

      expect_change_page("file_changed_removed", next_page_token)

      assert {:ok, %{signals: signals}} = poll("google.drive.file.changed", %{})

      assert [%{removed: false, time: time}, %{removed: true, time: time}] =
               Enum.filter(signals, &(&1[:file_id] == @added))
    end

    test "differ for google.drive.collection.changes across polls" do
      expect_folder_lookup("collection_changes_added")
      expect_change_page("collection_changes_added.2", @checkpoint)
      expect_folder_lookup("collection_changes_added")
      expect_change_page("file_changed_removed", @checkpoint)

      watch = %{collection_id: @watch_folder}
      assert {:ok, %{signals: before_deletion}} = poll("google.drive.collection.changes", watch)
      assert {:ok, %{signals: after_deletion}} = poll("google.drive.collection.changes", watch)

      assert %{removed?: false, changed_at: time} =
               update = record_signal(before_deletion, @added)

      assert %{removed?: true, changed_at: ^time} =
               removal = record_signal(after_deletion, @added)

      refute dedupe_key("google.drive.collection.changes", update) ==
               dedupe_key("google.drive.collection.changes", removal)
    end
  end

  defp poll(trigger_id, config, checkpoint \\ @checkpoint) do
    scopes = ["https://www.googleapis.com/auth/drive.metadata.readonly"]

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"},
        scopes: scopes
      })

    Connect.poll(Drive.integration(), trigger_id, config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp expect_folder_lookup(fixture, folder_id \\ @watch_folder) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/files/#{folder_id}"
      assert conn.query_params["fields"] == @folder_lookup_fields
      assert conn.query_params["supportsAllDrives"] == "true"

      body = LiveSmoke.fixture!(:google_drive, fixture)
      Req.Test.json(conn, Map.put(body, "id", folder_id))
    end)
  end

  defp expect_change_page(fixture, page_token, params \\ %{}) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/changes"
      assert conn.query_params["pageToken"] == page_token
      assert conn.query_params["includeRemoved"] == "true"
      assert Map.take(conn.query_params, Map.keys(params)) == params
      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, fixture))
    end)
  end

  # The key a host builds from the dedupe fields the trigger declares.
  defp dedupe_key(trigger_id, signal) do
    {:ok, %{dedupe: %{key: fields}}} = Connect.trigger(Drive.integration(), trigger_id)
    Enum.map(fields, &Map.get(signal, &1))
  end

  defp recorded_change(fixture, file_id) do
    :google_drive
    |> LiveSmoke.fixture!(fixture)
    |> Map.fetch!("changes")
    |> Enum.find(&(&1["fileId"] == file_id))
  end

  defp owner_permission(owner) do
    %{
      "id" => owner["permissionId"],
      "type" => "user",
      "role" => "owner",
      "emailAddress" => owner["emailAddress"],
      "displayName" => owner["displayName"]
    }
  end

  defp file_signal(signals, file_id), do: Enum.find(signals, &(&1[:file_id] == file_id))

  defp record_signal(signals, file_id),
    do: Enum.find(signals, &(&1[:provider_record_id] == file_id))
end
