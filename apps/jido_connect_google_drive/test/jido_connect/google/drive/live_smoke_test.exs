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
  alias Jido.Connect.Google.Drive.Client.Params

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

  # Byte limits for the export of GOOGLE_DOCS_TABBED_DOCUMENT_ID, whose plain
  # text holds this seed marker of its first tab.
  @small_limit 16
  @large_limit 1_048_576
  @tab_marker "jcl-marker-tab-first"

  # Two small JSON files whose bytes change when they are decoded and encoded
  # again: spacing, key order, a trailing zero, an escaped slash, and "ä", two
  # bytes but one character.
  @json_files [
    object:
      ~S({"jcl": "live-json", "b": 1, "a": [2.50, true, null], "path": "a\/b", "text": "ä"}) <>
        "\n",
    array: ~S([["name", "total"], ["Budget", 10]]) <> "\n"
  ]

  # A file ID that names no file of the test account.
  @missing_file_id "1JclLiveSmokeMissingFile000000000"

  # The seed script prepares GOOGLE_DRIVE_STARRED_FILE_ID next to an unstarred
  # twin of this name. No variable names the twin, so the selection test looks
  # it up by name in the starred file's folder.
  @unstarred_name "jcl-live unstarred.txt"
  @selection_fields "id,name,parents,starred,modifiedTime"

  # The edit test changes the Google Doc through the Docs API, the way an
  # editor would, and marks its insertion with this prefix and a per-run suffix.
  @docs_api "https://docs.googleapis.com/v1/documents/"
  @edit_marker_prefix "jcl-live-edit-"
  @google_doc_mime_type "application/vnd.google-apps.document"

  # Drive can log an edit made through the Docs API late: between 3 and about
  # 150 s after the edit in the runs of 2026-11-02. Reads for such an edit wait
  # up to 5 minutes.
  @docs_change_log_reads 150

  # Caller projections without `name`, for a file and for a change page.
  @fields_without_name "id,mimeType,parents,starred,modifiedTime"
  @change_fields_without_name "nextPageToken,newStartPageToken," <>
                                "changes(fileId,removed,time,changeType,driveId," <>
                                "file(id,mimeType,parents,trashed))"

  @google_sheet_mime_type "application/vnd.google-apps.spreadsheet"
  @apps_script_mime_type "application/vnd.google-apps.script"
  @apps_script_json "application/vnd.google-apps.script+json"
  @upload_api "https://www.googleapis.com/upload/drive/v3"

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

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_STARRED_FILE_ID"])
  test "reads the starred file and its unstarred twin with their flag and modification time",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    starred_id = env["GOOGLE_DRIVE_STARRED_FILE_ID"]

    # The expected values come from plain Drive requests that bypass the
    # package, so the comparison does not rest on the actions under test.
    assert %{status: 200, body: starred} =
             external(:get, "/files/#{starred_id}", token, params: [fields: @selection_fields])

    assert starred["starred"] == true,
           "the prepared file is no longer starred; run `seed.py drive` to restore it"

    %{"name" => starred_name, "parents" => [folder_id]} = starred
    in_folder = "'#{folder_id}' in parents and trashed = false"

    assert %{status: 200, body: %{"files" => twins}} =
             external(:get, "/files", token,
               params: [
                 q: "#{in_folder} and name = '#{@unstarred_name}'",
                 fields: "files(#{@selection_fields})"
               ]
             )

    # `seed.py drive` recreates a missing or trashed twin and unstars it, but
    # leaves extra copies in place.
    assert match?([%{"starred" => false}], twins),
           "expected one unstarred #{@unstarred_name} next to the starred file, found " <>
             "#{length(twins)}, #{Enum.count(twins, & &1["starred"])} of them starred; " <>
             "move every copy to the trash and run `seed.py drive` to create it again"

    [%{"id" => unstarred_id} = unstarred] = twins

    expected =
      Map.new([starred, unstarred], fn file ->
        {file["id"], %{starred?: file["starred"], modified_time: file["modifiedTime"]}}
      end)

    LiveSmoke.record(@req_options, :google_drive, "file_get_starred", @masked)

    assert {:ok, %{file: starred_file}} =
             invoke("google.drive.file.get", %{file_id: starred_id}, token)

    LiveSmoke.record(@req_options, :google_drive, "file_get_unstarred", @masked)

    assert {:ok, %{file: unstarred_file}} =
             invoke("google.drive.file.get", %{file_id: unstarred_id}, token)

    assert selection([starred_file, unstarred_file]) == expected

    # One file per page, so the flag and the time are read from two pages.
    LiveSmoke.record(@req_options, :google_drive, "files_list_starred", @masked)
    query = "#{in_folder} and (name = '#{starred_name}' or name = '#{@unstarred_name}')"
    pages = list_pages(%{query: query, page_size: 1}, token)

    assert length(pages) >= 2
    assert selection(Enum.flat_map(pages, & &1.files)) == expected
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

  # Drive declares no size for an export, so only the bytes it sends can stop
  # one. The exports under the small limit, under the large limit and one
  # byte below the export's length run before recording starts; only the
  # export at exactly its length is recorded.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "exports the tabbed document within max_bytes and stops below its length", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    input = %{file_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], mime_type: "text/plain"}

    assert {:error, %Connect.Error.ProviderError{reason: :limit_exceeded} = small} =
             invoke("google.drive.file.export", Map.put(input, :max_bytes, @small_limit), token)

    assert small.details.max_bytes == @small_limit
    refute Connect.Error.retryable?(small)
    refute inspect(small) =~ @tab_marker

    assert {:ok, %{file_content: %{size: size} = content}} =
             invoke("google.drive.file.export", Map.put(input, :max_bytes, @large_limit), token)

    assert size > @small_limit
    assert content.content =~ @tab_marker

    assert {:error, %Connect.Error.ProviderError{reason: :limit_exceeded}} =
             invoke("google.drive.file.export", Map.put(input, :max_bytes, size - 1), token)

    LiveSmoke.record(@req_options, :google_drive, "file_export_max_bytes", @masked)

    assert {:ok, %{file_content: ^content}} =
             invoke("google.drive.file.export", Map.put(input, :max_bytes, size), token)
  end

  # The size read of a download with max_bytes is the only request when
  # Drive declares more bytes than the limit; Finch's request events show it.
  # Neither the size taken from `google.drive.file.get` nor that stopped
  # download is recorded, only the download at the limit: its size read and
  # its content.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_SHARED_LINK_URL"])
  test "downloads the link-shared file at its declared size and stops one byte lower without a content request",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    assert {:ok, %{file_id: file_id} = link} = Link.parse(env["GOOGLE_DRIVE_SHARED_LINK_URL"])
    assert {:ok, %{file: %{size: size}}} = invoke("google.drive.file.get", link, token)
    assert is_integer(size) and size > 0

    {result, requests} =
      with_finch_requests(fn ->
        invoke("google.drive.file.download", Map.put(link, :max_bytes, size - 1), token)
      end)

    assert {:error, %Connect.Error.ProviderError{reason: :limit_exceeded}} = result
    assert [{"/drive/v3/files/" <> ^file_id, query}] = requests
    assert URI.decode_query(query)["fields"] == "size,mimeType"

    LiveSmoke.record(@req_options, :google_drive, "file_download_max_bytes", @masked)

    assert {:ok, %{file_content: %{file_id: ^file_id, size: ^size}}} =
             invoke("google.drive.file.download", Map.put(link, :max_bytes, size), token)
  end

  # Drive declares a size for a Google Doc, which has no bytes to download.
  # That size does not stop the download; Drive refuses it instead.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "a Google Doc's declared size does not stop a download with max_bytes", %{env: env} do
    LiveSmoke.record(@req_options, :google_drive, "file_download_max_bytes_google_doc", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 403} = error} =
             invoke(
               "google.drive.file.download",
               %{file_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], max_bytes: 1},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert error.reason == :http_error
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "a missing file's provider error does not carry the resource key", %{env: env} do
    resource_key = "0-JclLiveSmokeResourceKey"

    LiveSmoke.record(@req_options, :google_drive, "file_get_not_found", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 404} = error} =
             invoke(
               "google.drive.file.get",
               %{file_id: @missing_file_id, resource_key: resource_key},
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

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_EDIT_FILE_ID"])
  @tag write!(:google)
  @tag timeout: :timer.minutes(12)
  test "sees an external edit of the Google Doc by its ID and exports the new marker",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    file_id = env["GOOGLE_DRIVE_EDIT_FILE_ID"]
    marker = @edit_marker_prefix <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

    start = read_document(token, file_id)

    # A run that stopped before its cleanup leaves its marker in the document,
    # and `seed.py drive` does not reset the text of an existing document.
    assert edit_markers(start.text) == [],
           "GOOGLE_DRIVE_EDIT_FILE_ID still holds #{@edit_marker_prefix}… markers of an " <>
             "earlier run whose cleanup did not finish; delete them in Google Docs, for " <>
             "example with Find and replace, and run the test again"

    # Registered once the starting text is known: cleanup removes this run's
    # marker, also when an assertion below fails, and raises unless the
    # document holds its starting text again.
    on_exit(fn -> restore_document!(token, file_id, marker, start.digest) end)

    assert {:ok, %{signals: [], checkpoint: checkpoint}} =
             poll("google.drive.file.changed", %{}, nil, token)

    insert = %{insertText: %{endOfSegmentLocation: %{}, text: marker}}

    assert %{status: 200} =
             external_docs(:post, "#{file_id}:batchUpdate", token,
               json: %{requests: [insert], writeControl: %{requiredRevisionId: start.revision_id}}
             )

    await_change_log(token, checkpoint, [], &change_for(&1, file_id), @docs_change_log_reads)

    LiveSmoke.record(@req_options, :google_drive, "file_changed_edited", @masked)

    assert {:ok, %{signals: signals, checkpoint: cleanup_checkpoint}} =
             poll("google.drive.file.changed", %{}, checkpoint, token)

    # The signal names the document but not the edit: Drive sets `modifiedTime`
    # and `version` only when it logs a change and does not advance
    # `modifiedTime` for every edit, so a change that Drive logs late for an
    # earlier edit looks the same. Each run therefore waits below until Drive
    # has logged its cleanup; only an earlier run that failed or stopped before
    # that wait, or an edit outside this test, can stand in for this run's
    # edit. The export ties the signal's document to this run's marker.
    assert %{
             removed: false,
             change_type: "file",
             file: %{file_id: ^file_id, mime_type: @google_doc_mime_type}
           } = file_signal(signals, file_id)

    LiveSmoke.record(@req_options, :google_drive, "file_export_edited", @masked)

    assert {:ok, %{file_content: content}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: "text/plain"},
               token
             )

    assert Map.take(content, [:file_id, :mime_type]) ==
             %{file_id: file_id, mime_type: "text/plain"}

    exported? = String.contains?(content.content, marker)
    assert exported?, "the plain text export lacks this run's marker"

    assert remove_marker!(token, file_id, marker) == 1
    assert read_document(token, file_id).digest == start.digest

    # The cleanup is a Docs edit too, and Drive logs it as late as the
    # insertion. Waiting for it keeps that change out of the next run of this
    # test and out of the change polls that the other write tests record.
    await_change_log(
      token,
      cleanup_checkpoint,
      [],
      &change_for(&1, file_id),
      @docs_change_log_reads
    )
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

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "uploads a JSON object and a JSON array into the upload folder and downloads their exact bytes by ID",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]
    run = Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

    # Both uploads come first: the recorder writes every response after
    # `LiveSmoke.record/4` under its name, so only the downloads are recorded.
    uploads =
      for {kind, content} <- @json_files do
        name = "jcl-live json #{kind} #{run}.json"
        on_exit(fn -> delete_uploads_named(token, folder_id, name) end)

        assert {:ok, %{file: uploaded}} =
                 invoke(
                   "google.drive.file.upload",
                   %{
                     name: name,
                     content: content,
                     mime_type: "application/json",
                     parents: [folder_id]
                   },
                   token
                 )

        file_id = uploaded.file_id
        on_exit(fn -> delete_leftover(token, "/files/#{file_id}") end)

        # Drive computed the checksum from the bytes it stored.
        assert uploaded.parents == [folder_id]
        assert uploaded.md5_checksum == hex_digest(:md5, content)

        {kind, file_id, content}
      end

    for {kind, file_id, content} <- uploads do
      LiveSmoke.record(@req_options, :google_drive, "file_download_json_#{kind}", @masked)

      assert {:ok, %{file_content: downloaded}} =
               invoke("google.drive.file.download", %{file_id: file_id}, token)

      assert %{
               file_id: ^file_id,
               mime_type: "application/json",
               encoding: "utf-8",
               binary: false
             } = downloaded

      assert downloaded.size == byte_size(content)
      assert hex_digest(:sha256, downloaded.content) == hex_digest(:sha256, content)
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "a missing file's download error carries Google's message", %{env: env} do
    LiveSmoke.record(@req_options, :google_drive, "file_download_not_found", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 404} = error} =
             invoke(
               "google.drive.file.download",
               %{file_id: @missing_file_id},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert error.details.message == "File not found: #{@missing_file_id}."
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "a missing file's export error carries Google's message", %{env: env} do
    LiveSmoke.record(@req_options, :google_drive, "file_export_not_found", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 404} = error} =
             invoke(
               "google.drive.file.export",
               %{file_id: @missing_file_id, mime_type: "text/plain"},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert error.details.message == "File not found: #{@missing_file_id}."
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_STARRED_FILE_ID"])
  test "reads a file with caller fields that leave out name", %{env: env} do
    file_id = env["GOOGLE_DRIVE_STARRED_FILE_ID"]

    LiveSmoke.record(@req_options, :google_drive, "file_get_without_name", @masked)

    assert {:ok, %{file: file}} =
             invoke(
               "google.drive.file.get",
               %{file_id: file_id, fields: @fields_without_name},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert %{file_id: ^file_id, name: nil, starred?: true, parents: [_folder_id]} = file
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "polls a change with caller fields that leave out name", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]
    run = Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

    assert {:ok, %{signals: [], checkpoint: checkpoint}} =
             poll("google.drive.file.changed", %{}, nil, token)

    file_id = create_externally(token, "jcl-live unnamed #{run}.txt", "text/plain", folder_id)

    await_change_log(token, checkpoint, [], &change_for(&1, file_id))

    LiveSmoke.record(@req_options, :google_drive, "file_changed_without_name", @masked)

    assert {:ok, %{signals: signals}} =
             poll(
               "google.drive.file.changed",
               %{fields: @change_fields_without_name},
               checkpoint,
               token
             )

    assert %{removed: false, change_type: "file", file: file} = file_signal(signals, file_id)
    assert %{file_id: ^file_id, name: nil, parents: [^folder_id]} = file
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "creates a folder with caller fields that leave out name", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]

    # The response leaves the name out; the cleanup finds the folder by it
    # when the response is lost.
    name = "jcl-live unnamed folder #{Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)}"
    on_exit(fn -> delete_uploads_named(token, folder_id, name) end)

    LiveSmoke.record(@req_options, :google_drive, "folder_create_without_name", @masked)

    assert {:ok, %{folder: folder}} =
             invoke(
               "google.drive.folder.create",
               %{name: name, parents: [folder_id], fields: "id,mimeType,parents"},
               token
             )

    created_id = folder.folder_id
    on_exit(fn -> delete_leftover(token, "/files/#{created_id}") end)

    assert %{name: nil, parents: [^folder_id]} = folder
  end

  # Drive refuses most of these types and turns a folder-typed upload into an
  # empty folder, so the upload action rejects every one of them before the
  # request. The checks below send the multipart body the package builds,
  # outside the action, to watch what Drive does with it.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "rejects uploads typed as Google Workspace types, which Drive refuses or empties",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]
    run = Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
    content = "jcl-live typed upload #{run}\n"

    answers =
      for mime_type <- [
            @google_doc_mime_type,
            @google_sheet_mime_type,
            @apps_script_json,
            "Application/VND.Google-Apps.Document",
            @folder_mime_type
          ] do
        name = "jcl-live typed upload #{run} #{mime_type}"
        on_exit(fn -> delete_uploads_named(token, folder_id, name) end)

        upload = %{name: name, content: content, mime_type: mime_type, parents: [folder_id]}

        assert {:error,
                %Connect.Error.ValidationError{
                  reason: :unsupported_mime_type,
                  subject: :mime_type
                }} = invoke("google.drive.file.upload", upload, token)

        case external_upload(token, upload) do
          %{status: 200, body: %{"id" => id} = created} ->
            on_exit(fn -> delete_leftover(token, "/files/#{id}") end)
            {mime_type, 200, Map.take(created, ["mimeType", "quotaBytesUsed", "size"])}

          %{status: status, body: body} ->
            {mime_type, status, get_in(body, ["error", "message"])}
        end
      end

    # Drive refuses the lower-case document types as a bad request and the
    # upper-case Docs type as an invalid media type. The folder answer has no
    # `size`: Drive stored none of the bytes.
    assert answers == [
             {@google_doc_mime_type, 400, "Bad Request"},
             {@google_sheet_mime_type, 400, "Bad Request"},
             {@apps_script_json, 400, "Bad Request"},
             {"Application/VND.Google-Apps.Document", 400,
              "Invalid MIME type provided for the uploaded content."},
             {@folder_mime_type, 200, %{"mimeType" => @folder_mime_type, "quotaBytesUsed" => "0"}}
           ]
  end

  # Drive imports an Apps Script project from its JSON form into My Drive,
  # whatever `parents` names, so the test moves it into the upload folder
  # right away.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_UPLOAD_FOLDER_ID"])
  @tag write!(:google)
  test "exports an Apps Script project as the JSON bytes Drive sends", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    folder_id = env["GOOGLE_DRIVE_UPLOAD_FOLDER_ID"]
    run = Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)
    name = "jcl-live script #{run}"

    project =
      Jason.encode!(%{
        files: [
          %{
            name: "Code",
            type: "server_js",
            source: "function jclLive() {\n  return \"#{run}\";\n}\n"
          },
          %{name: "appsscript", type: "json", source: ~S({"exceptionLogging":"STACKDRIVER"})}
        ]
      })

    metadata = %{name: name, mimeType: @apps_script_mime_type, parents: [folder_id]}

    # The cleanup by name in My Drive covers an import whose response is lost
    # and that returns no ID.
    on_exit(fn -> delete_uploads_named(token, "root", name) end)

    assert %{status: 200, body: %{"id" => file_id, "parents" => [import_parent]}} =
             external_import(token, metadata, @apps_script_json, project)

    on_exit(fn -> delete_leftover(token, "/files/#{file_id}") end)

    assert %{status: 200, body: %{"parents" => [^folder_id]}} =
             external(:patch, "/files/#{file_id}", token,
               params: [addParents: folder_id, removeParents: import_parent, fields: "parents"],
               json: %{}
             )

    # The bytes Drive sends, read outside the package without decoding.
    assert %{status: 200, body: sent} =
             external(:get, "/files/#{file_id}/export", token,
               params: [mimeType: @apps_script_json],
               decode_body: false
             )

    assert String.contains?(sent, run)

    LiveSmoke.record(@req_options, :google_drive, "file_export_apps_script", @masked)

    assert {:ok, %{file_content: exported}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: @apps_script_json},
               token
             )

    assert %{
             file_id: ^file_id,
             mime_type: @apps_script_json,
             encoding: "utf-8",
             binary: false
           } = exported

    assert exported.size == byte_size(sent)
    assert hex_digest(:sha256, exported.content) == hex_digest(:sha256, sent)
  end

  # Every byte value, 20,480 times: exactly the multipart limit.
  defp upload_limit_content, do: :binary.copy(:binary.list_to_bin(Enum.to_list(0..255)), 20_480)

  defp hex_digest(algorithm, content),
    do: algorithm |> :crypto.hash(content) |> Base.encode16(case: :lower)

  # Runs `fun` and returns its result with the path and query of every
  # request that Finch started in this process meanwhile.
  defp with_finch_requests(fun) do
    handler_id = {__MODULE__, make_ref()}
    event = [:finch, :request, :start]
    :ok = :telemetry.attach(handler_id, event, &__MODULE__.forward_finch_request/4, self())

    try do
      result = fun.()
      {result, receive_finch_requests([])}
    after
      :telemetry.detach(handler_id)
    end
  end

  @doc false
  def forward_finch_request(_event, _measurements, %{request: request}, pid) do
    if self() == pid, do: send(pid, {:finch_request, request.path, request.query})
  end

  defp receive_finch_requests(requests) do
    receive do
      {:finch_request, path, query} -> receive_finch_requests([{path, query} | requests])
    after
      0 -> Enum.reverse(requests)
    end
  end

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

  defp selection(files),
    do: Map.new(files, &{&1.file_id, Map.take(&1, [:starred?, :modified_time])})

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

  defp await_change_log(access_token, page_token, params, done?, reads \\ @change_log_reads),
    do: await_change_log(access_token, page_token, params, done?, reads, 1)

  defp await_change_log(access_token, page_token, params, done?, reads, read) do
    cond do
      done?.(read_change_log(access_token, page_token, params)) ->
        :ok

      read < reads ->
        Process.sleep(2_000)
        await_change_log(access_token, page_token, params, done?, reads, read + 1)

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

  # The multipart body the upload action builds, sent outside the action.
  defp external_upload(access_token, upload) do
    {body, content_type} = Params.file_upload_multipart_body(upload)
    post_upload(access_token, body, content_type)
  end

  # A multipart upload whose metadata and media name different types, the
  # form of an import into a Google Workspace type.
  defp external_import(access_token, metadata, media_type, content) do
    boundary = "jcl-live-" <> Base.encode16(:crypto.strong_rand_bytes(6), case: :lower)

    body =
      IO.iodata_to_binary([
        "--#{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n",
        Jason.encode!(metadata),
        "\r\n--#{boundary}\r\nContent-Type: #{media_type}\r\n\r\n",
        content,
        "\r\n--#{boundary}--\r\n"
      ])

    post_upload(access_token, body, "multipart/related; boundary=#{boundary}")
  end

  defp post_upload(access_token, body, content_type) do
    Req.request!(
      method: :post,
      url: @upload_api <> "/files",
      params: [uploadType: "multipart", fields: "id,mimeType,parents,size,quotaBytesUsed"],
      headers: [{"content-type", content_type}],
      body: body,
      auth: {:bearer, access_token},
      retry: false
    )
  end

  defp external_docs(method, path, access_token, opts \\ []) do
    Req.request!(
      [method: method, url: @docs_api <> path, auth: {:bearer, access_token}, retry: false] ++
        opts
    )
  end

  # Reads the document's body text through the Docs API. Callers compare
  # digests and look for markers, so a failure never prints the document.
  defp read_document(access_token, document_id) do
    case external_docs(:get, document_id, access_token) do
      %{status: 200, body: %{"revisionId" => revision_id, "body" => %{"content" => content}}} ->
        text =
          for %{"paragraph" => %{"elements" => elements}} <- content,
              %{"textRun" => %{"content" => run}} <- elements,
              into: "",
              do: run

        %{revision_id: revision_id, text: text, digest: hex_digest(:sha256, text)}

      %{status: status} ->
        raise "could not read the body of live Docs document #{document_id}: HTTP #{status}"
    end
  end

  # The markers of this test in a document's text, so a failure names only
  # markers and no other document content.
  defp edit_markers(text),
    do: ~r/#{@edit_marker_prefix}[0-9a-f]*/ |> Regex.scan(text) |> List.flatten()

  # Deletes every occurrence of the marker and returns how many there were.
  defp remove_marker!(access_token, document_id, marker) do
    request = %{
      replaceAllText: %{containsText: %{text: marker, matchCase: true}, replaceText: ""}
    }

    case external_docs(:post, "#{document_id}:batchUpdate", access_token,
           json: %{requests: [request]}
         ) do
      %{status: 200, body: %{"replies" => [reply]}} ->
        get_in(reply, ["replaceAllText", "occurrencesChanged"]) || 0

      %{status: status} ->
        raise "cleanup could not remove the marker from live Docs document " <>
                "#{document_id}: HTTP #{status}"
    end
  end

  defp restore_document!(access_token, document_id, marker, digest) do
    if String.contains?(read_document(access_token, document_id).text, marker) do
      remove_marker!(access_token, document_id, marker)
    end

    unless read_document(access_token, document_id).digest == digest do
      raise "cleanup left live Docs document #{document_id} without its starting text"
    end
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
