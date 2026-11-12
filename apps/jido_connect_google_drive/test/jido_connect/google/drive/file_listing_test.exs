defmodule Jido.Connect.Google.Drive.FileListingTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.{Client, Fields}
  alias Jido.Connect.TestSupport.LiveSmoke

  # The folder the live test listed, its query, and the five pages of one file
  # each that Drive returned for it, in order.
  @folder_id "1K45M4kocXuEeMv_mrnUE_bzilqkb6rL9"
  @query "'#{@folder_id}' in parents and trashed = false"
  @folder_pages [
    "files_list_folder_page",
    "files_list_folder_page.2",
    "files_list_folder_page.3",
    "files_list_folder_page.4",
    "files_list_folder_page.5"
  ]
  @children [
    "1XN6NpT9HZsm8uiasW7kfMuz2t14zkxNuLpG2UZQxPHA",
    "1NsrjaNAf2qa6zbkr7wNUw5OAd98ePc6X",
    "1t3de328T902X6-aROW3-5vhyO7q8xzcl",
    "1CXJDDp5r_aKLYhJMOanLFZLFOa53dXIg",
    "1gxM0HVAtE-MRSf_5yKbX2Bw2VrmPfvUP"
  ]

  # The projection the live test sent for `files_list_caller_fields`.
  @caller_fields "nextPageToken,files(id,name,mimeType,parents)"

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

  test "files.list requests incompleteSearch when the caller sends no fields" do
    expect_preset_fields(Fields.file_list())

    assert {:ok, _listing} = Client.list_files(%{}, "token")
  end

  test "the permission-aware files.list preset requests incompleteSearch" do
    expect_preset_fields(Fields.file_list_with_permissions())

    assert {:ok, _listing} =
             Client.list_files(%{fields: Fields.file_list_with_permissions()}, "token")
  end

  test "files.list sends a caller-supplied fields expression unchanged" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.query_params["fields"] == @caller_fields
      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "files_list_caller_fields"))
    end)

    assert {:ok, listing} = Client.list_files(%{fields: @caller_fields}, "token")
    refute Map.has_key?(listing, :incomplete_search)
  end

  test "files.list pages through a folder and returns incomplete_search: false on every page" do
    pages = Enum.map(@folder_pages, &LiveSmoke.fixture!(:google_drive, &1))

    for {page, previous} <- Enum.zip(pages, [nil | pages]) do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_params["q"] == @query
        assert conn.query_params["pageSize"] == "1"
        assert conn.query_params["pageToken"] == (previous && previous["nextPageToken"])
        Req.Test.json(conn, page)
      end)
    end

    results = list_pages(%{query: @query, page_size: 1})

    assert Enum.flat_map(results, fn result -> Enum.map(result.files, & &1.file_id) end) ==
             @children

    assert Enum.map(results, & &1.incomplete_search) == [false, false, false, false, false]

    assert Enum.map(results, &Map.has_key?(&1, :next_page_token)) == [
             true,
             true,
             true,
             true,
             false
           ]
  end

  # Google returned incompleteSearch: false for every listing of the test
  # account, also with corpora=allDrives. This test sends the recorded final
  # page with the flag changed to true.
  test "files.list returns incomplete_search: true on a final page" do
    body =
      %{
        LiveSmoke.fixture!(:google_drive, "files_list_folder_page.5")
        | "incompleteSearch" => true
      }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.query_params["q"] == @query
      assert conn.query_params["corpora"] == "allDrives"
      assert conn.query_params["includeItemsFromAllDrives"] == "true"
      assert conn.query_params["supportsAllDrives"] == "true"
      Req.Test.json(conn, body)
    end)

    assert {:ok, result} = invoke(all_drives_query())

    assert result.incomplete_search == true
    refute Map.has_key?(result, :next_page_token)
  end

  # Drive may answer a page with no files and a nextPageToken, so an empty page
  # does not end the listing. This test sends the recorded first page without
  # its file and then the recorded final page.
  test "files.list keeps the continuation token of an empty page across all drives" do
    empty_page = %{LiveSmoke.fixture!(:google_drive, "files_list_folder_page") | "files" => []}
    final_page = LiveSmoke.fixture!(:google_drive, "files_list_folder_page.5")
    input = all_drives_query()

    for {body, page_token} <- [{empty_page, nil}, {final_page, empty_page["nextPageToken"]}] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_params["q"] == @query
        assert conn.query_params["pageToken"] == page_token
        assert conn.query_params["corpora"] == "allDrives"
        assert conn.query_params["includeItemsFromAllDrives"] == "true"
        assert conn.query_params["supportsAllDrives"] == "true"
        Req.Test.json(conn, body)
      end)
    end

    assert {:ok, first} = invoke(input)
    assert first.files == []
    assert first.next_page_token == empty_page["nextPageToken"]

    assert {:ok, last} = invoke(Map.put(input, :page_token, first.next_page_token))
    assert Enum.map(last.files, & &1.file_id) == [List.last(@children)]
    refute Map.has_key?(last, :next_page_token)
  end

  test "files.list returns no incomplete_search key when the response omits incompleteSearch" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.query_params["fields"] == @caller_fields
      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "files_list_caller_fields"))
    end)

    assert {:ok, result} = invoke(%{query: @query, page_size: 100, fields: @caller_fields})

    assert Enum.map(result.files, & &1.file_id) == @children
    refute Map.has_key?(result, :incomplete_search)
    refute Map.has_key?(result, :next_page_token)
  end

  test "files.list declares incomplete_search as a boolean output" do
    assert {:ok, action} = Connect.action(Drive, "google.drive.files.list")

    assert %Connect.Field{type: :boolean} =
             Enum.find(action.output, &(&1.name == :incomplete_search))
  end

  defp expect_preset_fields(preset) do
    assert String.starts_with?(preset, "nextPageToken,incompleteSearch,files(")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/files"
      assert conn.query_params["fields"] == preset

      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "files_list_folder_page.5"))
    end)
  end

  defp all_drives_query do
    %{
      query: @query,
      corpora: "allDrives",
      include_items_from_all_drives: true,
      supports_all_drives: true
    }
  end

  defp list_pages(input, results \\ []) do
    assert {:ok, result} = invoke(input)

    case result do
      %{next_page_token: token} ->
        list_pages(Map.put(input, :page_token, token), [result | results])

      _final ->
        Enum.reverse([result | results])
    end
  end

  defp invoke(input) do
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

    Connect.invoke(Drive.integration(), "google.drive.files.list", input,
      context: context,
      credential_lease: lease
    )
  end
end
