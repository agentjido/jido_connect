defmodule Jido.Connect.Google.Docs.BatchUpdateTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Docs
  alias Jido.Connect.TestSupport.LiveSmoke

  @moduletag :capture_log

  # The recordings come from the write test in `live_smoke_test.exs`, which
  # sends the same batches to the empty scratch document.
  @document_id "1t47PcdwCWroHLmzucoB5YxoFZRyUD9a8dymU8ju-pwE"
  @write_scope "https://www.googleapis.com/auth/documents"
  # The live run sent the revision it read before the insert; Google names it
  # in the stale-revision rejection. Any opaque string stands in for it here.
  @revision_before_insert "revision-read-before-the-insert"

  @marker_insert %{
    "insert_text" => %{
      "location" => %{"index" => 1, "tab_id" => "t.0"},
      "text" => "jcl-live-stale\n"
    }
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_docs,
      :google_docs_api_base_url,
      "https://docs.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_docs, :google_docs_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "sends an insert batch with snake_case keys and returns Google's write acknowledgement" do
    recorded = LiveSmoke.fixture!(:google_docs, "batch_update_insert")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/#{@document_id}:batchUpdate"

      assert wire_body(conn) == %{
               "requests" => [
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
               ],
               "writeControl" => %{"required_revision_id" => @revision_before_insert}
             }

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, result} =
             batch_update(%{
               document_id: @document_id,
               requests: [
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
               ],
               write_control: %{"required_revision_id" => @revision_before_insert}
             })

    # Google answers an insert with an empty reply object and sends no document.
    assert result == %{
             document_id: @document_id,
             replies: [%{}, %{}],
             write_control: %{
               "requiredRevisionId" => recorded["writeControl"]["requiredRevisionId"]
             }
           }
  end

  test "sends a range replacement batch in request order with the revision the insert returned" do
    inserted = LiveSmoke.fixture!(:google_docs, "batch_update_insert")
    recorded = LiveSmoke.fixture!(:google_docs, "batch_update_range_replacement")
    %{"writeControl" => %{"requiredRevisionId" => inserted_revision}} = inserted

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/#{@document_id}:batchUpdate"

      assert wire_body(conn) == %{
               "requests" => [
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
               ],
               "writeControl" => %{"required_revision_id" => inserted_revision}
             }

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, result} =
             batch_update(%{
               document_id: @document_id,
               requests: [
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
               ],
               write_control: %{"required_revision_id" => inserted_revision}
             })

    assert result == %{
             document_id: @document_id,
             replies: [%{}, %{}],
             write_control: %{
               "requiredRevisionId" => recorded["writeControl"]["requiredRevisionId"]
             }
           }

    refute result.write_control == inserted["writeControl"]
  end

  test "a stale required revision stays a provider error with Google's message" do
    recorded = LiveSmoke.fixture!(:google_docs, "batch_update_stale_revision")

    Req.Test.expect(__MODULE__, fn conn ->
      assert %{"writeControl" => %{"required_revision_id" => @revision_before_insert}} =
               wire_body(conn)

      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(recorded)
    end)

    assert {:error,
            %Connect.Error.ProviderError{
              reason: :http_error,
              status: 400,
              details: %{message: message}
            }} =
             batch_update(%{
               document_id: @document_id,
               requests: [@marker_insert],
               write_control: %{"required_revision_id" => @revision_before_insert}
             })

    assert message == recorded["error"]["message"]
    assert message =~ "does not match the latest revision"
  end

  test "sends a batch of exactly 100 requests" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert %{"requests" => requests} = wire_body(conn)
      assert length(requests) == 100
      Req.Test.json(conn, LiveSmoke.fixture!(:google_docs, "batch_update_insert"))
    end)

    assert {:ok, %{document_id: @document_id}} =
             batch_update(%{document_id: @document_id, requests: marker_inserts(100)})
  end

  # Each input breaks the envelope or names an operation outside the
  # allowlist, so none of them may reach Google.
  for {edit, description, reason} <- [
        {:document_id_missing, "document_id is missing", :input},
        {:requests_missing, "requests is missing", :input},
        {:requests_not_a_list, "requests is not a list", :input},
        {:requests_empty, "requests is empty", :invalid_batch_update_requests},
        {:too_many_requests, "requests holds 101 operations", :invalid_batch_update_requests},
        {:request_not_a_map, "a request is not a map", :input},
        {:request_without_operation, "a request names no operation",
         :invalid_batch_update_request},
        {:request_with_two_operations, "a request names two operations",
         :invalid_batch_update_request},
        {:delete_table, "a request is delete_table, which Docs does not have",
         :unsupported_batch_update_operation},
        {:camel_case_operation, "a request names the camelCase insertText",
         :unsupported_batch_update_operation},
        {:write_control_not_a_map, "write_control is not a map", :input}
      ] do
    test "rejects the batch before any HTTP request when #{description}" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, {:http_request, conn.request_path})
        Req.Test.json(conn, %{})
      end)

      assert {:error, %Connect.Error.ValidationError{reason: unquote(reason)}} =
               batch_update(envelope(unquote(edit)))

      refute_received {:http_request, _path}
    end
  end

  # Google's batchUpdate response carries no document. These cases add a
  # recorded document read to the recorded insert response.
  test "returns an inline document as a plain map" do
    document = LiveSmoke.fixture!(:google_docs, "document_without_tabs_content")
    Req.Test.expect(__MODULE__, &Req.Test.json(&1, insert_response_with(document)))

    assert {:ok, %{document_id: @document_id, document: inline}} =
             batch_update(%{document_id: @document_id, requests: [@marker_insert]})

    assert %{tabs: [], body: body} = inline
    assert inline.document_id == document["documentId"]
    assert body == document["body"]
  end

  for {edit, description} <- [
        document_not_a_map: "the inline document is not a map",
        tab_not_a_map: "a tab of the inline document is not a map",
        child_tabs_not_a_list: "a tab's childTabs in the inline document is not a list"
      ] do
    test "returns an invalid response error when #{description}" do
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, insert_response_with(inline(unquote(edit)))))

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_response}} =
               batch_update(%{document_id: @document_id, requests: [@marker_insert]})
    end
  end

  test "the action metadata lists the write acknowledgement fields" do
    action =
      Enum.find(Docs.integration().actions, &(&1.id == "google.docs.document.batch_update"))

    assert Enum.map(action.output, &{&1.name, &1.type}) == [
             {:document_id, :string},
             {:write_control, :map},
             {:replies, {:array, :map}},
             {:document, :map}
           ]

    assert action.risk == :destructive
    assert action.confirmation == :always
    assert action.scopes == [@write_scope]
  end

  defp envelope(:document_id_missing), do: %{requests: [@marker_insert]}
  defp envelope(:requests_missing), do: %{document_id: @document_id}

  defp envelope(:requests_not_a_list),
    do: %{document_id: @document_id, requests: @marker_insert}

  defp envelope(:requests_empty), do: %{document_id: @document_id, requests: []}

  defp envelope(:too_many_requests),
    do: %{document_id: @document_id, requests: marker_inserts(101)}

  defp envelope(:request_not_a_map),
    do: %{document_id: @document_id, requests: ["insert_text"]}

  defp envelope(:request_without_operation),
    do: %{document_id: @document_id, requests: [%{}]}

  defp envelope(:request_with_two_operations) do
    two = Map.put(@marker_insert, "delete_content_range", %{"range" => %{"start_index" => 1}})
    %{document_id: @document_id, requests: [two]}
  end

  # Docs has no deleteTable request; Google rejects the name as an unknown field.
  defp envelope(:delete_table) do
    %{
      document_id: @document_id,
      requests: [%{"delete_table" => %{"table_start_location" => %{"index" => 1}}}]
    }
  end

  defp envelope(:camel_case_operation) do
    %{
      document_id: @document_id,
      requests: [%{"insertText" => %{"location" => %{"index" => 1}, "text" => "jcl-live"}}]
    }
  end

  defp envelope(:write_control_not_a_map),
    do: %{document_id: @document_id, requests: [@marker_insert], write_control: "revision"}

  defp marker_inserts(count), do: List.duplicate(@marker_insert, count)

  defp insert_response_with(document) do
    :google_docs
    |> LiveSmoke.fixture!("batch_update_insert")
    |> Map.put("document", document)
  end

  defp inline(:document_not_a_map), do: "not a document"

  defp inline(:tab_not_a_map) do
    :google_docs
    |> LiveSmoke.fixture!("document_with_tabs_content")
    |> put_in(["tabs", Access.at(0)], "not a tab")
  end

  defp inline(:child_tabs_not_a_list) do
    :google_docs
    |> LiveSmoke.fixture!("document_with_tabs_content")
    |> update_in(["tabs", Access.at(1), "childTabs"], &%{"tab" => hd(&1)})
  end

  defp wire_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end

  defp batch_update(input) do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google_docs,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: [@write_scope]
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
        provider: :google_docs,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"},
        scopes: [@write_scope]
      })

    Connect.invoke(Docs.integration(), "google.docs.document.batch_update", input,
      context: context,
      credential_lease: lease
    )
  end
end
