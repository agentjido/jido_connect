defmodule Jido.Connect.Google.Docs.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Docs
  alias Jido.Connect.Google.Docs.Client

  @req_options {:jido_connect_google, :google_req_options}
  # The test account's refresh token holds documents, not documents.readonly,
  # so the connection and the lease declare the scope the token carries.
  @documents_scope "https://www.googleapis.com/auth/documents"

  # GOOGLE_DRIVE_ONLY_ACCESS_TOKEN is minted from the same refresh token,
  # narrowed to this scope; see docs/live_smoke_tests.md.
  @drive_scope "https://www.googleapis.com/auth/drive"
  @tokeninfo "https://oauth2.googleapis.com/tokeninfo"

  # The prepared document has the top-level tabs First and Second and the
  # child tab Nested under Second, each holding one seed marker.
  @first_marker "jcl-marker-tab-first"
  @second_marker "jcl-marker-tab-second"
  @nested_marker "jcl-marker-tab-nested"

  # The scratch document is empty between runs: one tab `t.0` whose body holds
  # only the final newline. The write test fills it with test markers at
  # indexes that hold for an empty document, and empties it again on exit.
  # `batch_update_test.exs` replays the recordings with the same batches.
  @docs_api "https://docs.googleapis.com/v1/documents/"

  # Inserted in this order at index 1, so the first marker ends up on top.
  @insert_batch [
    %{
      "insert_text" => %{
        "location" => %{"index" => 1, "tab_id" => "t.0"},
        "text" => "jcl-live-second\n"
      }
    },
    %{
      "insert_text" => %{
        "location" => %{"index" => 1, "tab_id" => "t.0"},
        "text" => "jcl-live-first\n"
      }
    }
  ]

  # Replaces the second marker, indexes 16 to 31, and keeps its newline.
  @range_replacement_batch [
    %{
      "delete_content_range" => %{
        "range" => %{"start_index" => 16, "end_index" => 31, "tab_id" => "t.0"}
      }
    },
    %{
      "insert_text" => %{
        "location" => %{"index" => 16, "tab_id" => "t.0"},
        "text" => "jcl-live-replaced"
      }
    }
  ]

  @text_after_replacement "jcl-live-first\njcl-live-replaced\n\n"

  @stale_batch [
    %{
      "insert_text" => %{
        "location" => %{"index" => 1, "tab_id" => "t.0"},
        "text" => "jcl-live-stale\n"
      }
    }
  ]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"])
  test "reads the scratch document", %{env: env} do
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :google_docs, "document")

    assert {:ok, document} =
             Client.get_document(
               %{document_id: env["GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"]},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert is_map(document)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "reads every tab body of the tabbed document, including the nested tab", %{env: env} do
    LiveSmoke.record(@req_options, :google_docs, "document_with_tabs_content")

    assert {:ok, %{document: document}} =
             get_document(
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], include_tabs_content: true},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert_every_tab_with_its_marker(document)
  end

  # The connection and the lease hold only drive, and Google's tokeninfo
  # endpoint confirms, outside the recorder, that the token holds nothing
  # else. A pass therefore shows that Google answers a Docs read under drive.
  @tag env!(["GOOGLE_DRIVE_ONLY_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "reads every tab body of the tabbed document under a drive-only grant", %{env: env} do
    token = env["GOOGLE_DRIVE_ONLY_ACCESS_TOKEN"]

    assert token_scopes(token) == [@drive_scope]

    LiveSmoke.record(@req_options, :google_docs, "document_with_tabs_content_drive_grant")

    assert {:ok, %{document: document}} =
             invoke(
               "google.docs.document.get",
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], include_tabs_content: true},
               token,
               [@drive_scope]
             )

    assert_every_tab_with_its_marker(document)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "without tab content returns only the first tab in the legacy body", %{env: env} do
    LiveSmoke.record(@req_options, :google_docs, "document_without_tabs_content")

    assert {:ok, %{document: document}} =
             get_document(
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], include_tabs_content: false},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert_only_first_tab_in_legacy_body(document)
  end

  # The client sends includeTabsContent only when the input sets it, so this
  # request carries no such parameter.
  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "an omitted include_tabs_content returns what false returns", %{env: env} do
    LiveSmoke.record(@req_options, :google_docs, "document_tabs_content_omitted")

    assert {:ok, %{document: document}} =
             get_document(
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"]},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert_only_first_tab_in_legacy_body(document)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"])
  @tag write!(:google)
  test "applies an insertion and a range replacement and rejects a stale revision",
       %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    document_id = env["GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"]

    assert %{tab_id: "t.0", revision_id: initial_revision, text: "\n"} =
             read_scratch(token, document_id)

    # Registered after the document proved empty and before the first write.
    # Cleanup then removes only what this test wrote, also when an assertion
    # below fails, and never touches a document that was not empty.
    on_exit(fn -> empty_scratch_document!(token, document_id) end)

    LiveSmoke.record(@req_options, :google_docs, "batch_update_insert")

    assert {:ok, inserted} =
             batch_update(
               %{
                 document_id: document_id,
                 requests: @insert_batch,
                 write_control: %{"required_revision_id" => initial_revision}
               },
               token
             )

    assert %{
             document_id: ^document_id,
             replies: [%{}, %{}],
             write_control: %{"requiredRevisionId" => inserted_revision}
           } = inserted

    refute Map.has_key?(inserted, :document)

    assert read_scratch(token, document_id).text ==
             "jcl-live-first\njcl-live-second\n\n"

    LiveSmoke.record(@req_options, :google_docs, "batch_update_range_replacement")

    assert {:ok, replaced} =
             batch_update(
               %{
                 document_id: document_id,
                 requests: @range_replacement_batch,
                 write_control: %{"required_revision_id" => inserted_revision}
               },
               token
             )

    assert %{
             document_id: ^document_id,
             replies: [%{}, %{}],
             write_control: %{"requiredRevisionId" => replaced_revision}
           } = replaced

    assert replaced_revision != inserted_revision

    assert read_scratch(token, document_id).text == @text_after_replacement

    LiveSmoke.record(@req_options, :google_docs, "batch_update_stale_revision")

    assert {:error, %Connect.Error.ProviderError{reason: :http_error, status: 400} = error} =
             batch_update(
               %{
                 document_id: document_id,
                 requests: @stale_batch,
                 write_control: %{"required_revision_id" => initial_revision}
               },
               token
             )

    assert error.details.message =~ "does not match the latest revision"

    assert read_scratch(token, document_id).text == @text_after_replacement
  end

  defp assert_every_tab_with_its_marker(document) do
    assert [
             %{tab_id: first_id, title: "First", body: first_body, child_tabs: []},
             %{
               tab_id: second_id,
               title: "Second",
               body: second_body,
               child_tabs: [
                 %{tab_id: nested_id, title: "Nested", body: nested_body, child_tabs: []}
               ]
             }
           ] = document.tabs

    tab_ids = [first_id, second_id, nested_id]
    assert Enum.all?(tab_ids, &(is_binary(&1) and &1 != ""))
    assert Enum.uniq(tab_ids) == tab_ids

    assert text(first_body) =~ @first_marker
    assert text(second_body) =~ @second_marker
    assert text(nested_body) =~ @nested_marker
  end

  defp assert_only_first_tab_in_legacy_body(document) do
    assert document.tabs == []
    assert text(document.body) =~ @first_marker
    refute text(document.body) =~ @second_marker
    refute text(document.body) =~ @nested_marker
  end

  # The token goes in the form body, not the URL, and a failure names only
  # the status: Google's answer also carries the OAuth client ID.
  defp token_scopes(access_token) do
    case Req.post!(@tokeninfo, form: [access_token: access_token], retry: false) do
      %{status: 200, body: %{"scope" => scope}} -> String.split(scope)
      %{status: status} -> flunk("tokeninfo answered HTTP #{status}")
    end
  end

  defp text(%{"content" => content}) do
    for %{"paragraph" => %{"elements" => elements}} <- content,
        %{"textRun" => %{"content" => run}} <- elements,
        into: "",
        do: run
  end

  # Reads and cleanup bypass the package's Req options, so the recorder only
  # writes the batch updates under test.
  defp read_scratch(access_token, document_id) do
    assert %{status: 200, body: %{"revisionId" => revision_id, "tabs" => [tab]}} =
             external(:get, document_id, access_token, params: [includeTabsContent: true])

    %{"tabProperties" => %{"tabId" => tab_id}, "documentTab" => %{"body" => body}} = tab
    %{"content" => content} = body

    %{
      tab_id: tab_id,
      revision_id: revision_id,
      text: text(body),
      end_index: content |> List.last() |> Map.fetch!("endIndex")
    }
  end

  # Deletes everything but the final newline, which a Docs body always keeps,
  # and raises unless the document is empty afterwards.
  defp empty_scratch_document!(access_token, document_id) do
    %{tab_id: tab_id, end_index: end_index} = read_scratch(access_token, document_id)

    if end_index > 2 do
      range = %{startIndex: 1, endIndex: end_index - 1, tabId: tab_id}

      %{status: status} =
        external(:post, "#{document_id}:batchUpdate", access_token,
          json: %{requests: [%{deleteContentRange: %{range: range}}]}
        )

      unless status == 200, do: raise("cleanup could not empty the scratch document: #{status}")
    end

    case read_scratch(access_token, document_id) do
      %{text: "\n", end_index: 2} -> :ok
      _other -> raise "the scratch document is not empty after cleanup"
    end
  end

  defp external(method, path, access_token, opts) do
    Req.request!(
      [method: method, url: @docs_api <> path, auth: {:bearer, access_token}, retry: false] ++
        opts
    )
  end

  defp batch_update(input, access_token) do
    invoke("google.docs.document.batch_update", input, access_token)
  end

  defp get_document(input, access_token) do
    invoke("google.docs.document.get", input, access_token)
  end

  defp invoke(action_id, input, access_token, scopes \\ [@documents_scope]) do
    connection =
      Connect.Connection.new!(%{
        id: "live_smoke",
        provider: :google_docs,
        profile: :user,
        tenant_id: "live_smoke",
        owner_type: :app_user,
        owner_id: "live_smoke",
        status: :connected,
        scopes: scopes
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
        provider: :google_docs,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: scopes
      })

    Connect.invoke(Docs.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
