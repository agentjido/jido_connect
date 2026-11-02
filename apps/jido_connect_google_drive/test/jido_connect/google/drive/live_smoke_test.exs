defmodule Jido.Connect.Google.Drive.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.{Client, Link}

  @req_options {:jido_connect_google, :google_req_options}
  @drive_scope "https://www.googleapis.com/auth/drive"
  @shortcut_mime_type "application/vnd.google-apps.shortcut"

  # Account identifiers and the content thumbnail URL that no offline test needs.
  @masked [fields: ["permissionId", "photoLink", "thumbnailLink"]]

  # Upper bound for the paging loops, so a provider that keeps returning
  # `nextPageToken` fails the test instead of looping.
  @max_pages 20

  # A caller-supplied projection without `incompleteSearch`.
  @caller_list_fields "nextPageToken,files(id,name,mimeType,parents)"

  # Prepared data of the test account: GOOGLE_DRIVE_FOLDER_ID holds this many
  # direct children outside the trash and one trashed child. The seed script
  # restores them, possibly under new IDs.
  @folder_children 5

  @folder_mime_type "application/vnd.google-apps.folder"

  # Drive lists drive-level changes (`changeType: "drive"`) only to a poll that
  # includes shared-drive items.
  @all_drives %{include_items_from_all_drives: true, supports_all_drives: true}

  # The write tests change Drive the way a person or another app would: with
  # plain requests that bypass the package's Req options, so the recorder only
  # writes the polls under test.
  @drive_api "https://www.googleapis.com/drive/v3"

  # Drive's change log can lag behind a write; reads wait this often, 2 s apart.
  @change_log_reads 15
  @change_log_fields "nextPageToken,changes(fileId,removed,changeType,driveId,file(id,trashed))"

  @upload_limit 5_242_880

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "reads the Drive about resource", %{env: env} do
    LiveSmoke.record(@req_options, :google_drive, "about")

    assert {:ok, about} = Client.get_about(%{}, env["GOOGLE_ACCESS_TOKEN"])
    assert is_map(about)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_FOLDER_ID"])
  test "lists the prepared folder's direct children one file per page", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    in_folder = "'#{env["GOOGLE_DRIVE_FOLDER_ID"]}' in parents"
    query = "#{in_folder} and trashed = false"

    # The known direct children: one unfiltered listing, which also returns
    # trashed children, filtered here instead of by the provider.
    assert {:ok, %{files: children} = unfiltered} =
             invoke("google.drive.files.list", %{query: in_folder, page_size: 100}, token)

    refute Map.has_key?(unfiltered, :next_page_token)

    assert Enum.any?(children, & &1.trashed?),
           "the prepared folder has no trashed child; Drive deletes trashed files " <>
             "after 30 days, run `seed.py drive` to restore it"

    known_ids = for file <- children, not file.trashed?, do: file.file_id
    assert length(known_ids) == @folder_children

    LiveSmoke.record(@req_options, :google_drive, "files_list_caller_fields", @masked)

    assert {:ok, listing} =
             invoke(
               "google.drive.files.list",
               %{query: query, page_size: 100, fields: @caller_list_fields},
               token
             )

    assert Enum.sort(file_ids(listing)) == Enum.sort(known_ids)
    refute Map.has_key?(listing, :incomplete_search)

    LiveSmoke.record(@req_options, :google_drive, "files_list_folder_page", @masked)
    pages = list_pages(%{query: query, page_size: 1}, token)

    assert length(pages) >= 2
    assert Enum.sort(Enum.flat_map(pages, &file_ids/1)) == Enum.sort(known_ids)
    refute Map.has_key?(List.last(pages), :next_page_token)

    for page <- pages do
      assert is_boolean(page[:incomplete_search])
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_SHARED_LINK_URL", "GOOGLE_DRIVE_SHORTCUT_ID"])
  test "resolves the link-shared file from its URL and reads the shortcut's target", %{env: env} do
    assert {:ok, %{file_id: file_id} = link} = Link.parse(env["GOOGLE_DRIVE_SHARED_LINK_URL"])

    LiveSmoke.record(@req_options, :google_drive, "file_get_shared_link", @masked)

    assert {:ok, %{file: file}} =
             invoke("google.drive.file.get", link, env["GOOGLE_ACCESS_TOKEN"])

    assert file.file_id == file_id
    assert file.resource_key == link[:resource_key]
    assert is_binary(file.mime_type)

    LiveSmoke.record(@req_options, :google_drive, "file_get_shortcut", @masked)

    assert {:ok, %{file: shortcut}} =
             invoke(
               "google.drive.file.get",
               %{file_id: env["GOOGLE_DRIVE_SHORTCUT_ID"]},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert shortcut.mime_type == @shortcut_mime_type
    assert shortcut.shortcut_target_id == file.file_id
    assert shortcut.shortcut_target_mime_type == file.mime_type
    assert shortcut.shortcut_target_resource_key == file.resource_key
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_SHARED_LINK_URL"])
  test "downloads the link-shared file from its URL", %{env: env} do
    assert {:ok, %{file_id: file_id} = link} = Link.parse(env["GOOGLE_DRIVE_SHARED_LINK_URL"])

    LiveSmoke.record(@req_options, :google_drive, "file_download", @masked)

    assert {:ok, %{file_content: %{file_id: ^file_id, size: size}}} =
             invoke("google.drive.file.download", link, env["GOOGLE_ACCESS_TOKEN"])

    assert size > 0
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_EDIT_FILE_ID"])
  test "exports the Google Doc as plain text", %{env: env} do
    file_id = env["GOOGLE_DRIVE_EDIT_FILE_ID"]

    LiveSmoke.record(@req_options, :google_drive, "file_export", @masked)

    assert {:ok, %{file_content: %{file_id: ^file_id, mime_type: "text/plain"}}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: "text/plain"},
               env["GOOGLE_ACCESS_TOKEN"]
             )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "a missing file's provider error does not carry the resource key", %{env: env} do
    resource_key = "0-JclLiveSmokeResourceKey"

    LiveSmoke.record(@req_options, :google_drive, "file_get_not_found", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 404} = error} =
             invoke(
               "google.drive.file.get",
               %{file_id: "1JclLiveSmokeMissingFile000000000", resource_key: resource_key},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    refute inspect(error) =~ resource_key
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_WATCH_FOLDER_ID"])
  @tag write!(:google)
  test "sees files added to the watch folder and a deleted file by its ID", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_WATCH_FOLDER_ID"]
    watch = %{collection_id: folder_id}
    started_at = DateTime.utc_now()

    assert {:ok, %{signals: [], checkpoint: collection_checkpoint}} =
             poll("google.drive.collection.changes", watch, nil, token)

    assert {:ok, %{signals: [], checkpoint: file_checkpoint}} =
             poll("google.drive.file.changed", %{}, nil, token)

    added_id = create_externally(token, "jcl-live added", "text/plain", folder_id)
    subfolder_id = create_externally(token, "jcl-live subfolder", @folder_mime_type, folder_id)
    nested_id = create_externally(token, "jcl-live nested", "text/plain", subfolder_id)

    await_change_log(token, collection_checkpoint, [], fn changes ->
      Enum.all?([added_id, subfolder_id, nested_id], &change_for(changes, &1))
    end)

    LiveSmoke.record(@req_options, :google_drive, "collection_changes_added", @masked)

    assert {:ok, %{signals: signals}} =
             poll("google.drive.collection.changes", watch, collection_checkpoint, token)

    assert %{
             collection_match: "yes",
             change_type: "updated",
             record: %{created_at: created_at, parents: [^folder_id]}
           } = record_signal(signals, added_id)

    assert {:ok, created, 0} = DateTime.from_iso8601(created_at)
    assert DateTime.after?(created, started_at)

    assert %{collection_match: "yes"} = record_signal(signals, subfolder_id)

    assert %{collection_match: "no", record: %{parents: [^subfolder_id]}} =
             record_signal(signals, nested_id)

    delete_externally(token, added_id)

    await_change_log(token, file_checkpoint, [], fn changes ->
      match?(%{"removed" => true}, change_for(changes, added_id))
    end)

    LiveSmoke.record(@req_options, :google_drive, "file_changed_removed", @masked)

    assert {:ok, %{signals: signals}} =
             poll("google.drive.file.changed", %{}, file_checkpoint, token)

    assert %{file_id: ^added_id, removed: true, change_type: "file"} =
             removal = file_signal(signals, added_id)

    assert Enum.sort(Map.keys(removal)) == [:change_type, :file_id, :removed, :time]
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_WATCH_FOLDER_ID"])
  @tag write!(:google)
  test "tells a trashed file, a removed file and a drive-level change apart", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_WATCH_FOLDER_ID"]
    watch = %{collection_id: folder_id}

    trashed_id = create_externally(token, "jcl-live trashed", "text/plain", folder_id)
    removed_id = create_externally(token, "jcl-live removed", "text/plain", folder_id)
    drive_id = create_shared_drive_externally(token, "jcl-live drive")

    assert {:ok, %{signals: [], checkpoint: file_checkpoint}} =
             poll("google.drive.file.changed", @all_drives, nil, token)

    assert {:ok, %{signals: [], checkpoint: collection_checkpoint}} =
             poll("google.drive.collection.changes", watch, nil, token)

    assert %{status: 200} =
             external(:patch, "/files/#{trashed_id}", token, json: %{trashed: true})

    delete_externally(token, removed_id)

    assert %{status: 200} =
             external(:patch, "/drives/#{drive_id}", token,
               json: %{name: "jcl-live drive renamed"}
             )

    all_drives = [includeItemsFromAllDrives: true, supportsAllDrives: true]

    await_change_log(token, file_checkpoint, all_drives, fn changes ->
      match?(
        %{"removed" => false, "file" => %{"trashed" => true}},
        change_for(changes, trashed_id)
      ) and
        match?(%{"removed" => true}, change_for(changes, removed_id)) and
        Enum.any?(changes, &match?(%{"changeType" => "drive", "driveId" => ^drive_id}, &1))
    end)

    LiveSmoke.record(@req_options, :google_drive, "file_changed_mixed", @masked)

    assert {:ok, %{signals: signals}} =
             poll("google.drive.file.changed", @all_drives, file_checkpoint, token)

    assert %{removed: false, change_type: "file", file: %{trashed?: true}} =
             file_signal(signals, trashed_id)

    assert %{removed: true} = removal = file_signal(signals, removed_id)
    refute Map.has_key?(removal, :file)

    assert [drive_change] =
             Enum.filter(signals, &match?(%{change_type: "drive", drive_id: ^drive_id}, &1))

    refute Map.has_key?(drive_change, :file_id)
    refute Map.has_key?(drive_change, :file)

    LiveSmoke.record(@req_options, :google_drive, "collection_changes_trashed", @masked)

    assert {:ok, %{signals: signals}} =
             poll("google.drive.collection.changes", watch, collection_checkpoint, token)

    assert %{collection_match: "yes", removed?: false, record: %{trashed?: true}} =
             record_signal(signals, trashed_id)

    assert %{collection_match: "unknown", change_type: "deleted", removed?: true} =
             record_signal(signals, removed_id)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "uploads exactly 5,242,880 bytes into the upload folder and reads them back by ID",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]
    content = upload_limit_content()

    # A name of this run only, so a concurrent run's cleanup leaves the file
    # alone. The cleanup by name covers an upload whose response is lost and
    # that returns no ID.
    name = "jcl-live upload #{Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)}.bin"
    on_exit(fn -> delete_uploads_named(token, folder_id, name) end)

    LiveSmoke.record(@req_options, :google_drive, "file_upload", @masked)

    assert {:ok, %{file: uploaded}} =
             invoke(
               "google.drive.file.upload",
               %{
                 name: name,
                 content_base64: Base.encode64(content),
                 mime_type: "application/octet-stream",
                 parents: [folder_id]
               },
               token
             )

    # Deletes the file by ID, also when it landed outside the upload folder.
    file_id = uploaded.file_id
    on_exit(fn -> delete_leftover(token, "/files/#{file_id}") end)

    assert uploaded.parents == [folder_id]
    assert uploaded.size == @upload_limit

    LiveSmoke.record(@req_options, :google_drive, "file_upload_get", @masked)

    assert {:ok, %{file: read_back}} = invoke("google.drive.file.get", %{file_id: file_id}, token)
    assert read_back.parents == [folder_id]
    assert read_back.md5_checksum == hex_digest(:md5, content)

    LiveSmoke.record(@req_options, :google_drive, "file_upload_download", @masked)

    assert {:ok, %{file_content: downloaded}} =
             invoke("google.drive.file.download", %{file_id: file_id}, token)

    assert downloaded.file_id == file_id
    assert downloaded.size == @upload_limit

    assert hex_digest(:sha256, Base.decode64!(downloaded.content_base64)) ==
             hex_digest(:sha256, content)
  end

  # Every byte value, 20,480 times: exactly the multipart limit.
  defp upload_limit_content, do: :binary.copy(:binary.list_to_bin(Enum.to_list(0..255)), 20_480)

  defp hex_digest(algorithm, content),
    do: algorithm |> :crypto.hash(content) |> Base.encode16(case: :lower)

  defp delete_uploads_named(access_token, folder_id, name) do
    assert %{status: 200, body: %{"files" => files}} =
             external(:get, "/files", access_token,
               params: [q: "name = '#{name}' and '#{folder_id}' in parents", fields: "files(id)"]
             )

    for %{"id" => id} <- files, do: delete_leftover(access_token, "/files/#{id}")
  end

  defp list_pages(input, access_token, pages \\ []) do
    assert length(pages) < @max_pages
    assert {:ok, page} = invoke("google.drive.files.list", input, access_token)

    case page do
      %{next_page_token: token} ->
        list_pages(Map.put(input, :page_token, token), access_token, [page | pages])

      _final ->
        Enum.reverse([page | pages])
    end
  end

  defp file_ids(%{files: files}), do: Enum.map(files, & &1.file_id)

  defp file_signal(signals, file_id), do: Enum.find(signals, &(&1[:file_id] == file_id))

  defp record_signal(signals, file_id),
    do: Enum.find(signals, &(&1[:provider_record_id] == file_id))

  defp change_for(changes, file_id), do: Enum.find(changes, &(&1["fileId"] == file_id))

  # Every object a test creates is deleted when the test exits. Deleting a
  # folder also deletes the descendants the test user owns.
  defp create_externally(access_token, name, mime_type, parent_id) do
    assert %{status: 200, body: %{"id" => id}} =
             external(:post, "/files", access_token,
               json: %{name: name, mimeType: mime_type, parents: [parent_id]}
             )

    on_exit(fn -> delete_leftover(access_token, "/files/#{id}") end)
    id
  end

  defp create_shared_drive_externally(access_token, name) do
    request_id = "jcl-live-#{System.system_time(:millisecond)}"

    assert %{status: 200, body: %{"id" => id}} =
             external(:post, "/drives", access_token,
               params: [requestId: request_id],
               json: %{name: name}
             )

    on_exit(fn -> delete_leftover(access_token, "/drives/#{id}") end)
    id
  end

  defp delete_externally(access_token, file_id) do
    assert %{status: 204} = external(:delete, "/files/#{file_id}", access_token)
  end

  # An object that is already gone, 404 or 410, counts as deleted. Any other
  # answer raises with the object's path and status, without the response
  # body, so an object left in the shared account fails the test.
  defp delete_leftover(access_token, path) do
    case external(:delete, path, access_token) do
      %{status: status} when status in 200..299 or status in [404, 410] ->
        :ok

      %{status: status} ->
        raise "cleanup could not delete live Drive object #{path}: HTTP #{status}"
    end
  end

  defp await_change_log(access_token, page_token, params, done?, read \\ 1) do
    cond do
      done?.(read_change_log(access_token, page_token, params)) ->
        :ok

      read < @change_log_reads ->
        Process.sleep(2_000)
        await_change_log(access_token, page_token, params, done?, read + 1)

      true ->
        flunk("Drive's change log lacked the expected changes after #{read} reads")
    end
  end

  # Drive can end a page with `nextPageToken` before `pageSize` is reached, so
  # a read follows the token through the last page.
  defp read_change_log(access_token, page_token, params, changes \\ [], pages \\ 0) do
    assert pages < @max_pages

    assert %{status: 200, body: body} =
             external(:get, "/changes", access_token,
               params:
                 [
                   pageToken: page_token,
                   pageSize: 1000,
                   includeRemoved: true,
                   fields: @change_log_fields
                 ] ++ params
             )

    changes = changes ++ Map.get(body, "changes", [])

    case body do
      %{"nextPageToken" => next_page_token} ->
        read_change_log(access_token, next_page_token, params, changes, pages + 1)

      _last_page ->
        changes
    end
  end

  defp external(method, path, access_token, opts \\ []) do
    Req.request!(
      [method: method, url: @drive_api <> path, auth: {:bearer, access_token}, retry: false] ++
        opts
    )
  end

  defp poll(trigger_id, config, checkpoint, access_token) do
    Connect.poll(
      Drive.integration(),
      trigger_id,
      config,
      [checkpoint: checkpoint] ++ connect_opts(access_token)
    )
  end

  defp invoke(action_id, input, access_token) do
    Connect.invoke(Drive.integration(), action_id, input, connect_opts(access_token))
  end

  defp connect_opts(access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_smoke",
        provider: :google,
        profile: :user,
        tenant_id: "live_smoke",
        owner_type: :app_user,
        owner_id: "live_smoke",
        status: :connected,
        scopes: [@drive_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_smoke",
        actor: %{id: "live_smoke", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live_smoke",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: [@drive_scope]
      })

    [context: context, credential_lease: lease]
  end
end
