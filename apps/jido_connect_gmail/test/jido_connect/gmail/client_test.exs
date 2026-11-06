defmodule Jido.Connect.Gmail.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Gmail.{Attachment, Client, Draft, Label, Message, Profile, Thread, Watch}
  alias Jido.Connect.Gmail.Client.Response
  alias Jido.Connect.TestSupport.LiveSmoke

  defmodule RecordedBodyAdapter do
    # Req adapter that reports the method, path and body of each request to
    # the calling test process and answers with the recording of the same
    # method and path: the live trash and untrash answers for the disposable
    # message and its one-message thread.

    @recordings ~w(message_trash message_untrash thread_trash thread_untrash)

    def run(request) do
      send(self(), {:gmail_request, request.method, request.url.path, request.body})
      method = request.method |> Atom.to_string() |> String.upcase()

      %{"status" => status, "headers" => headers, "body" => body} =
        Enum.find_value(@recordings, fn name ->
          recording = recording!(name)

          if recording["request"] == %{"method" => method, "path" => request.url.path},
            do: recording
        end) || raise "no recording of #{method} #{request.url.path}"

      {request,
       Req.Response.new(
         status: status,
         headers: Map.take(headers, ["content-type"]),
         body: Jason.encode!(body)
       )}
    end

    # A whole recording: the request, the status, the headers and the body.
    def recording!(name) do
      ["test", "fixtures", "gmail", "recorded", "#{name}.json"]
      |> Path.join()
      |> File.read!()
      |> Jason.decode!()
    end
  end

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gmail, :gmail_api_base_url, "https://gmail.test")
    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_gmail, :gmail_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets Gmail profile" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/profile"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, %{
        "emailAddress" => "user@example.com",
        "messagesTotal" => 10,
        "threadsTotal" => 5,
        "historyId" => "123"
      })
    end)

    assert {:ok, %Profile{} = profile} = Client.get_profile(%{}, "token")
    assert profile.email_address == "user@example.com"
    assert profile.messages_total == 10
  end

  test "lists Gmail labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/labels"

      Req.Test.json(conn, %{
        "labels" => [
          %{
            "id" => "INBOX",
            "name" => "INBOX",
            "type" => "system"
          }
        ]
      })
    end)

    assert {:ok, %{labels: [%Label{} = label]}} = Client.list_labels(%{}, "token")
    assert label.label_id == "INBOX"
    assert label.name == "INBOX"
  end

  test "gets Gmail labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/labels/Label_123"

      Req.Test.json(conn, %{
        "id" => "Label_123",
        "name" => "Customers",
        "type" => "user"
      })
    end)

    assert {:ok, %Label{} = label} = Client.get_label(%{label_id: "Label_123"}, "token")
    assert label.label_id == "Label_123"
    assert label.name == "Customers"
  end

  test "lists Gmail messages" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages"
      assert conn.query_params["q"] == "from:sender@example.com"
      assert conn.query_params["labelIds"] == "INBOX"
      assert conn.query_params["maxResults"] == "10"
      assert conn.query_params["includeSpamTrash"] == "false"

      Req.Test.json(conn, %{
        "messages" => [
          %{"id" => "msg123", "threadId" => "thread123"}
        ],
        "nextPageToken" => "next",
        "resultSizeEstimate" => 1
      })
    end)

    assert {:ok, %{messages: [%Message{} = message], next_page_token: "next"}} =
             Client.list_messages(
               %{
                 query: "from:sender@example.com",
                 label_ids: ["INBOX"],
                 page_size: 10,
                 include_spam_trash: false
               },
               "token"
             )

    assert message.message_id == "msg123"
    assert message.thread_id == "thread123"
  end

  test "pages a recorded query search to its empty last page" do
    %{
      "messages" => [%{"id" => message_id, "threadId" => thread_id}],
      "nextPageToken" => next_page_token,
      "resultSizeEstimate" => estimate
    } = first_page = LiveSmoke.fixture!(:gmail, "messages_list_query")

    %{"resultSizeEstimate" => 0} = last_page = LiveSmoke.fixture!(:gmail, "messages_list_query.6")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/gmail/v1/users/me/messages"

      assert conn.query_params == %{
               "q" => "subject:report",
               "maxResults" => "1",
               "includeSpamTrash" => "false"
             }

      Req.Test.json(conn, first_page)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.query_params["pageToken"] == next_page_token
      Req.Test.json(conn, last_page)
    end)

    params = %{query: "subject:report", label_ids: [], page_size: 1, include_spam_trash: false}

    assert {:ok,
            %{
              messages: [%Message{message_id: ^message_id, thread_id: ^thread_id}],
              next_page_token: ^next_page_token,
              result_size_estimate: ^estimate
            }} = Client.list_messages(params, "token")

    assert {:ok, %{messages: [], result_size_estimate: 0} = end_of_search} =
             Client.list_messages(Map.put(params, :page_token, next_page_token), "token")

    refute Map.has_key?(end_of_search, :next_page_token)
  end

  test "returns the recorded rejection of a query search under gmail.metadata" do
    %{"error" => %{"message" => message}} =
      rejection = LiveSmoke.fixture!(:gmail, "messages_list_query_metadata_scope")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.query_params["q"] == "subject:report"

      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(rejection)
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              status: 403,
              details: %{message: ^message}
            }} = Client.list_messages(%{query: "subject:report", page_size: 1}, "token")
  end

  test "returns provider errors for malformed Gmail list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages"

      Req.Test.json(conn, %{
        "messages" => [
          %{"threadId" => "thread123"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_messages(%{}, "token")
  end

  test "response handlers reject malformed successful collection bodies" do
    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_label_list_response({:ok, %{status: 200, body: %{"labels" => :bad}}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_message_list_response(
               {:ok, %{status: 200, body: %{"messages" => :bad}}}
             )

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_draft_list_response({:ok, %{status: 200, body: %{"drafts" => :bad}}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_thread_list_response(
               {:ok, %{status: 200, body: %{"threads" => :bad}}}
             )

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_history_list_response({:ok, %{status: 200, body: "bad body"}})
  end

  test "response handlers reject malformed successful single-object bodies" do
    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_profile_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_label_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_message_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_thread_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_watch_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_attachment_response({:ok, %{status: 200, body: "bad body"}})

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Response.handle_draft_response({:ok, %{status: 200, body: "bad body"}})
  end

  test "gets Gmail message metadata without body data" do
    # Recorded with this request under gmail.metadata: Gmail sends the
    # requested header, the IDs, labels, history ID, date and size, and no
    # snippet and no part of the body.
    %{
      "id" => message_id,
      "payload" => %{"headers" => [%{"name" => "Subject", "value" => subject}]}
    } =
      recorded = LiveSmoke.fixture!(:gmail, "message_metadata_subject")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages/#{message_id}"
      assert conn.query_params["format"] == "metadata"
      assert conn.query_params["metadataHeaders"] == "Subject"

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %Message{} = message} =
             Client.get_message(%{message_id: message_id, metadata_headers: ["Subject"]}, "token")

    assert message.message_id == message_id
    assert [%{name: "Subject", value: ^subject}] = message.headers

    assert {message.history_id, message.internal_date, message.size_estimate} ==
             {recorded["historyId"], recorded["internalDate"], recorded["sizeEstimate"]}

    refute Map.has_key?(message.payload_summary, :body_size)
  end

  test "lists Gmail threads" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads"
      assert conn.query_params["q"] == "label:inbox"
      assert conn.query_params["labelIds"] == "INBOX"

      Req.Test.json(conn, %{
        "threads" => [
          %{"id" => "thread123", "historyId" => "456"}
        ],
        "nextPageToken" => "next-thread",
        "resultSizeEstimate" => 1
      })
    end)

    assert {:ok, %{threads: [%Thread{} = thread], next_page_token: "next-thread"}} =
             Client.list_threads(%{query: "label:inbox", label_ids: ["INBOX"]}, "token")

    assert thread.thread_id == "thread123"
    assert thread.history_id == "456"
  end

  test "gets Gmail thread metadata without body data" do
    # Recorded with this request under gmail.metadata: the two messages of
    # the archive pair, each with the requested header only.
    %{"id" => thread_id, "messages" => [%{"id" => first_id}, %{"id" => reply_id}]} =
      recorded = LiveSmoke.fixture!(:gmail, "thread_metadata_subject")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads/#{thread_id}"
      assert conn.query_params["format"] == "metadata"
      assert conn.query_params["metadataHeaders"] == "Subject"

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %Thread{} = thread} =
             Client.get_thread(%{thread_id: thread_id, metadata_headers: ["Subject"]}, "token")

    assert thread.thread_id == thread_id
    assert thread.history_id == recorded["historyId"]

    assert [%Message{message_id: ^first_id} = first, %Message{message_id: ^reply_id} = reply] =
             thread.messages

    for message <- [first, reply] do
      assert [%{name: "Subject"}] = message.headers
      refute Map.has_key?(message.payload_summary, :body_size)
    end
  end

  test "handles Gmail draft lifecycle endpoints" do
    # No drafts.get was recorded. Gmail answers it with the draft ID and the
    # draft's message in the form messages.get returns for the same format
    # and headers, so the draft here wraps message_metadata_subject, the
    # metadata read of an inbox message. That read ran under gmail.metadata,
    # which ScopeResolver never grants drafts.get; it asks for gmail.compose,
    # gmail.modify, gmail.readonly or the full mail scope. Under such a grant
    # Gmail's format=metadata answer also carries a snippet and a payload
    # mimeType and no empty partId, as message_metadata_archived shows, and a
    # real draft's message carries the DRAFT label. The test asserts none of
    # these fields.
    %{"id" => draft_message_id} =
      draft_message = LiveSmoke.fixture!(:gmail, "message_metadata_subject")

    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/gmail/v1/users/me/drafts"} ->
          assert conn.query_params["q"] == "to:customer@example.com"
          assert conn.query_params["maxResults"] == "5"
          assert conn.query_params["pageToken"] == "next"
          assert conn.query_params["includeSpamTrash"] == "false"

          Req.Test.json(conn, %{
            "drafts" => [
              %{
                "id" => "draft123",
                "message" => %{"id" => "draft-message123", "threadId" => "thread123"}
              }
            ],
            "nextPageToken" => "next-draft",
            "resultSizeEstimate" => 1
          })

        {"GET", "/gmail/v1/users/me/drafts/draft123"} ->
          assert conn.query_params["format"] == "metadata"
          assert conn.query_params["metadataHeaders"] == "Subject"

          Req.Test.json(conn, %{"id" => "draft123", "message" => draft_message})

        {"DELETE", "/gmail/v1/users/me/drafts/draft123"} ->
          Req.Test.json(conn, %{})
      end
    end)

    assert {:ok, %{drafts: [%Draft{} = draft], next_page_token: "next-draft"}} =
             Client.list_drafts(
               %{
                 query: "to:customer@example.com",
                 page_size: 5,
                 page_token: "next",
                 include_spam_trash: false
               },
               "token"
             )

    assert draft.draft_id == "draft123"
    assert draft.message.message_id == "draft-message123"

    assert {:ok, %Draft{} = draft} =
             Client.get_draft(%{draft_id: "draft123", metadata_headers: ["Subject"]}, "token")

    assert draft.draft_id == "draft123"
    assert %Message{message_id: ^draft_message_id, headers: [%{name: "Subject"}]} = draft.message

    assert {:ok, %{deleted?: true, draft_id: "draft123"}} =
             Client.delete_draft(%{draft_id: "draft123"}, "token")
  end

  test "returns provider errors for malformed Gmail single-object responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/threads/thread123"

      Req.Test.json(conn, %{
        "id" => "thread123",
        "messages" => [
          %{"threadId" => "thread123"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.get_thread(%{thread_id: "thread123"}, "token")
  end

  test "lists Gmail history message additions without body data" do
    # message_received_history is the live poll of an inserted message and
    # its reply. Gmail lists each addition with its ID, thread and labels
    # only, beside the record's `messages` entry. The label and deletion
    # records come from the change poll's recording, message_changed_history:
    # the next test reads the labelsRemoved record of its first page, and
    # only the message changed poll tests in gmail_test.exs read labelsAdded
    # and messagesDeleted, from its later pages.
    %{"history" => recorded_records, "historyId" => history_id} =
      page = LiveSmoke.fixture!(:gmail, "message_received_history")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/history"
      assert conn.query_params["startHistoryId"] == "123"
      assert conn.query_params["labelId"] == "INBOX"
      assert conn.query_params["maxResults"] == "50"
      assert conn.query_params["pageToken"] == "page-2"
      assert conn.query_params["historyTypes"] == "messageAdded"

      Req.Test.json(conn, page)
    end)

    assert {:ok, %{history: [_original, _reply] = records, history_id: ^history_id} = result} =
             Client.list_history(
               %{
                 start_history_id: "123",
                 label_id: "INBOX",
                 page_size: 50,
                 page_token: "page-2",
                 history_types: ["messageAdded"]
               },
               "token"
             )

    refute Map.has_key?(result, :next_page_token)

    for {record, recorded} <- Enum.zip(records, recorded_records) do
      %{
        "id" => record_id,
        "messages" => [%{"id" => message_id}],
        "messagesAdded" => [%{"message" => added}]
      } = recorded

      assert %{
               history_id: ^record_id,
               messages: [%Message{message_id: ^message_id}],
               messages_added: [%Message{} = message]
             } = record

      assert record |> Map.keys() |> Enum.sort() == [:history_id, :messages, :messages_added]

      assert {message.message_id, message.thread_id, message.label_ids} ==
               {added["id"], added["threadId"], added["labelIds"]}

      assert {message.snippet, message.headers} == {nil, []}
    end
  end

  test "requests the three change types as repeated historyTypes without a label filter" do
    %{
      "history" => [_only, %{"id" => archive_id, "labelsRemoved" => [archived]}],
      "nextPageToken" => next_page_token
    } = page = LiveSmoke.fixture!(:gmail, "message_changed_history")

    %{"message" => %{"id" => archived_id}, "labelIds" => removed_label_ids} = archived

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/gmail/v1/users/me/history"

      assert conn.query_string |> URI.query_decoder() |> Enum.sort() == [
               {"historyTypes", "labelAdded"},
               {"historyTypes", "labelRemoved"},
               {"historyTypes", "messageDeleted"},
               {"maxResults", "2"},
               {"startHistoryId", "15659"}
             ]

      Req.Test.json(conn, page)
    end)

    assert {:ok,
            %{
              history: [
                _only,
                %{
                  history_id: ^archive_id,
                  labels_removed: [
                    %{message: %Message{message_id: ^archived_id}, label_ids: ^removed_label_ids}
                  ]
                }
              ],
              next_page_token: ^next_page_token
            }} =
             Client.list_history(
               %{
                 start_history_id: "15659",
                 page_size: 2,
                 history_types: ["messageDeleted", "labelAdded", "labelRemoved"]
               },
               "token"
             )
  end

  test "trash and untrash requests carry an empty body, so Google receives a Content-Length" do
    # Mint sends Content-Length only with a request body, and Google answers a
    # POST without one with 411 Length Required, as the live change poll test
    # saw for google.gmail.message.trash. A plug cannot tell a missing body
    # from an empty one, so RecordedBodyAdapter replaces the network and
    # answers with the live recordings of the four calls.
    Application.put_env(:jido_connect_google, :google_req_options, adapter: RecordedBodyAdapter)
    %{"body" => %{"id" => message_id}} = RecordedBodyAdapter.recording!("message_trash")
    %{"body" => %{"id" => thread_id}} = RecordedBodyAdapter.recording!("thread_trash")

    assert {:ok, %Message{message_id: ^message_id, thread_id: ^thread_id, label_ids: ["TRASH"]}} =
             Client.trash_message(%{message_id: message_id}, "token")

    assert {:ok, %Message{message_id: ^message_id, thread_id: ^thread_id, label_ids: []}} =
             Client.untrash_message(%{message_id: message_id}, "token")

    assert {:ok,
            %Thread{
              thread_id: ^thread_id,
              messages: [%Message{message_id: ^message_id, label_ids: ["TRASH"]}]
            }} = Client.trash_thread(%{thread_id: thread_id}, "token")

    assert {:ok,
            %Thread{
              thread_id: ^thread_id,
              messages: [%Message{message_id: ^message_id, label_ids: []}]
            }} = Client.untrash_thread(%{thread_id: thread_id}, "token")

    for path <- [
          "/gmail/v1/users/me/messages/#{message_id}/trash",
          "/gmail/v1/users/me/messages/#{message_id}/untrash",
          "/gmail/v1/users/me/threads/#{thread_id}/trash",
          "/gmail/v1/users/me/threads/#{thread_id}/untrash"
        ] do
      assert_received {:gmail_request, :post, ^path, ""}
    end
  end

  test "returns provider errors for malformed Gmail history records" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/history"

      Req.Test.json(conn, %{
        "history" => [
          %{"id" => "124", "messagesAdded" => nil}
        ],
        "historyId" => "125"
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.list_history(
               %{start_history_id: "123", history_types: ["messageAdded"]},
               "token"
             )
  end

  test "gets Gmail message attachments" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages/msg123/attachments/att123"

      Req.Test.json(conn, %{
        "attachmentId" => "att123",
        "size" => 12,
        "data" => "Ym9keS1ieXRlcw"
      })
    end)

    assert {:ok, %Attachment{} = attachment} =
             Client.get_attachment(%{message_id: "msg123", attachment_id: "att123"}, "token")

    assert attachment.attachment_id == "att123"
    assert attachment.size == 12
    assert attachment.data == "Ym9keS1ieXRlcw"
  end

  test "starts and stops Gmail watches" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/gmail/v1/users/me/watch"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "topicName" => "projects/project-1/topics/gmail",
                   "labelIds" => ["INBOX"],
                   "labelFilterBehavior" => "include"
                 }

          Req.Test.json(conn, %{
            "historyId" => "126",
            "expiration" => "1710000000000"
          })

        {"POST", "/gmail/v1/users/me/stop"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{}
          Req.Test.json(conn, %{})
      end
    end)

    assert {:ok, %Watch{} = watch} =
             Client.start_watch(
               %{
                 topic_name: "projects/project-1/topics/gmail",
                 label_ids: ["INBOX"],
                 label_filter_behavior: "include"
               },
               "token"
             )

    assert watch.history_id == "126"
    assert watch.expiration == "1710000000000"

    assert {:ok, %{stopped?: true}} = Client.stop_watch(%{}, "token")
  end

  # The send and draft answers below are the live run of
  # send_live_smoke_test.exs: a new mail and its reply in the same thread,
  # and a reply draft created and then replaced under the same draft ID.

  test "sends Gmail messages, with the thread ID of a reply beside its raw message" do
    original = RecordedBodyAdapter.recording!("message_send")
    reply = RecordedBodyAdapter.recording!("message_send_reply")
    thread_id = original["body"]["threadId"]
    assert reply["body"]["threadId"] == thread_id

    for {recording, request_body} <- [
          {original, %{"raw" => "encoded-message"}},
          {reply, %{"raw" => "encoded-reply", "threadId" => thread_id}}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert %{"method" => conn.method, "path" => conn.request_path} == recording["request"]
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == request_body
        Req.Test.json(conn, recording["body"])
      end)
    end

    assert {:ok, %Message{} = message} = Client.send_message(%{raw: "encoded-message"}, "token")
    assert message.message_id == original["body"]["id"]
    assert message.thread_id == thread_id
    assert message.label_ids == ["SENT"]

    assert {:ok, %Message{} = message} =
             Client.send_message(%{raw: "encoded-reply", thread_id: thread_id}, "token")

    assert message.message_id == reply["body"]["id"]
    assert message.thread_id == thread_id
    assert message.label_ids == ["SENT"]
  end

  test "creates Gmail drafts" do
    recording = RecordedBodyAdapter.recording!("draft_create")

    %{"id" => draft_id, "message" => %{"id" => message_id, "threadId" => thread_id}} =
      recording["body"]

    Req.Test.expect(__MODULE__, fn conn ->
      assert %{"method" => conn.method, "path" => conn.request_path} == recording["request"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "message" => %{"raw" => "encoded-message", "threadId" => thread_id}
             }

      Req.Test.json(conn, recording["body"])
    end)

    assert {:ok, %Draft{} = draft} =
             Client.create_draft(%{raw: "encoded-message", thread_id: thread_id}, "token")

    assert draft.draft_id == draft_id
    assert draft.message.message_id == message_id
    assert draft.message.thread_id == thread_id
    assert draft.message.label_ids == ["DRAFT"]
  end

  test "replaces a Gmail draft under its draft ID with a new message" do
    created = RecordedBodyAdapter.recording!("draft_create")
    recording = RecordedBodyAdapter.recording!("draft_update")

    %{"id" => draft_id, "message" => %{"id" => message_id, "threadId" => thread_id}} =
      recording["body"]

    assert created["body"]["id"] == draft_id
    assert created["body"]["message"]["id"] != message_id

    Req.Test.expect(__MODULE__, fn conn ->
      assert %{"method" => conn.method, "path" => conn.request_path} == recording["request"]
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "message" => %{"raw" => "updated-message", "threadId" => thread_id}
             }

      Req.Test.json(conn, recording["body"])
    end)

    assert {:ok, %Draft{} = draft} =
             Client.update_draft(
               %{draft_id: draft_id, raw: "updated-message", thread_id: thread_id},
               "token"
             )

    assert draft.draft_id == draft_id
    assert draft.message.message_id == message_id
    assert draft.message.thread_id == thread_id
    assert draft.message.label_ids == ["DRAFT"]
  end

  test "sends a draft ID with a slash, a space and a question mark as one encoded path segment" do
    %{"body" => draft} = RecordedBodyAdapter.recording!("draft_update")
    path = "/gmail/v1/users/me/drafts/a%2Fb%20c%3F"

    Req.Test.expect(__MODULE__, fn conn ->
      assert {conn.method, conn.request_path} == {"PUT", path}
      Req.Test.json(conn, draft)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert {conn.method, conn.request_path} == {"GET", path}
      Req.Test.json(conn, draft)
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert {conn.method, conn.request_path} == {"DELETE", path}
      Req.Test.json(conn, %{})
    end)

    assert {:ok, %Draft{}} =
             Client.update_draft(%{draft_id: "a/b c?", raw: "updated-message"}, "token")

    assert {:ok, %Draft{}} = Client.get_draft(%{draft_id: "a/b c?"}, "token")

    assert {:ok, %{deleted?: true, draft_id: "a/b c?"}} =
             Client.delete_draft(%{draft_id: "a/b c?"}, "token")
  end

  test "sends Gmail drafts" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/drafts/send"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"id" => "draft123"}

      Req.Test.json(conn, %{
        "id" => "sent-draft123",
        "threadId" => "thread123",
        "labelIds" => ["SENT"]
      })
    end)

    assert {:ok, %Message{} = message} = Client.send_draft(%{draft_id: "draft123"}, "token")
    assert message.message_id == "sent-draft123"
  end

  test "creates Gmail labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/labels"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "name" => "Customers",
               "messageListVisibility" => "show",
               "labelListVisibility" => "labelShow"
             }

      Req.Test.json(conn, %{
        "id" => "Label_123",
        "name" => "Customers",
        "type" => "user",
        "messageListVisibility" => "show"
      })
    end)

    assert {:ok, %Label{} = label} =
             Client.create_label(
               %{
                 name: "Customers",
                 message_list_visibility: "show",
                 label_list_visibility: "labelShow"
               },
               "token"
             )

    assert label.label_id == "Label_123"
    assert label.name == "Customers"
  end

  test "applies Gmail message labels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/gmail/v1/users/me/messages/msg123/modify"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "addLabelIds" => ["Label_123"],
               "removeLabelIds" => []
             }

      Req.Test.json(conn, %{
        "id" => "msg123",
        "threadId" => "thread123",
        "labelIds" => ["INBOX", "Label_123"]
      })
    end)

    assert {:ok, %Message{} = message} =
             Client.apply_message_labels(
               %{message_id: "msg123", add_label_ids: ["Label_123"], remove_label_ids: []},
               "token"
             )

    assert message.label_ids == ["INBOX", "Label_123"]
  end

  describe "message label changes" do
    # The answers are messages.modify responses that
    # labels_live_smoke_test.exs recorded for one message of the archive pair
    # and for the ID of a message deleted for good.

    test "sends a message ID with a slash and a space as one encoded path segment" do
      archived = LiveSmoke.fixture!(:gmail, "message_modify_archive")

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/gmail/v1/users/me/messages/a%2Fb%20c/modify"
        Req.Test.json(conn, archived)
      end)

      assert {:ok, %Message{}} =
               Client.apply_message_labels(
                 %{message_id: "a/b c", add_label_ids: [], remove_label_ids: ["INBOX"]},
                 "token"
               )
    end

    test "removing only UNREAD sends empty additions and returns the recorded message" do
      %{"request" => %{"method" => "POST", "path" => path}, "body" => read} =
        RecordedBodyAdapter.recording!("message_modify_read")

      %{"id" => message_id, "threadId" => thread_id, "labelIds" => label_ids} = read
      assert path == "/gmail/v1/users/me/messages/#{message_id}/modify"

      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.request_path} == {"POST", path}
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"addLabelIds" => [], "removeLabelIds" => ["UNREAD"]}
        Req.Test.json(conn, read)
      end)

      assert {:ok,
              %Message{message_id: ^message_id, thread_id: ^thread_id, label_ids: ^label_ids} =
                message} =
               Client.apply_message_labels(
                 %{message_id: message_id, remove_label_ids: ["UNREAD"]},
                 "token"
               )

      refute "UNREAD" in message.label_ids
    end

    test "returns the recorded 404 for an unknown message ID as a provider error" do
      %{"request" => %{"method" => "POST", "path" => path}, "status" => 404, "body" => rejection} =
        RecordedBodyAdapter.recording!("message_modify_unknown_id")

      ["/", "gmail", "v1", "users", "me", "messages", message_id, "modify"] = Path.split(path)
      %{"error" => %{"message" => error_message}} = rejection

      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.request_path} == {"POST", path}

        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(rejection)
      end)

      assert {:error,
              %Jido.Connect.Error.ProviderError{
                provider: :google,
                status: 404,
                details: %{message: ^error_message}
              }} =
               Client.apply_message_labels(
                 %{message_id: message_id, add_label_ids: [], remove_label_ids: ["INBOX"]},
                 "token"
               )
    end
  end

  test "handles Gmail message lifecycle endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/gmail/v1/users/me/messages/batchModify"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "ids" => ["msg123", "msg456"],
                   "addLabelIds" => ["Label_123"],
                   "removeLabelIds" => ["UNREAD"]
                 }

          Req.Test.json(conn, %{})

        {"POST", "/gmail/v1/users/me/messages/msg123/trash"} ->
          Req.Test.json(conn, %{
            "id" => "msg123",
            "threadId" => "thread123",
            "labelIds" => ["TRASH"]
          })

        {"POST", "/gmail/v1/users/me/messages/msg123/untrash"} ->
          Req.Test.json(conn, %{
            "id" => "msg123",
            "threadId" => "thread123",
            "labelIds" => ["INBOX"]
          })

        {"DELETE", "/gmail/v1/users/me/messages/msg123"} ->
          Req.Test.json(conn, %{})

        {"POST", "/gmail/v1/users/me/messages/batchDelete"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"ids" => ["msg123", "msg456"]}
          Req.Test.json(conn, %{})
      end
    end)

    assert {:ok,
            %{
              modified?: true,
              message_ids: ["msg123", "msg456"],
              add_label_ids: ["Label_123"],
              remove_label_ids: ["UNREAD"]
            }} =
             Client.batch_modify_messages(
               %{
                 message_ids: ["msg123", "msg456"],
                 add_label_ids: ["Label_123"],
                 remove_label_ids: ["UNREAD"]
               },
               "token"
             )

    assert {:ok, %Message{label_ids: ["TRASH"]}} =
             Client.trash_message(%{message_id: "msg123"}, "token")

    assert {:ok, %Message{label_ids: ["INBOX"]}} =
             Client.untrash_message(%{message_id: "msg123"}, "token")

    assert {:ok, %{deleted?: true, message_id: "msg123"}} =
             Client.delete_message(%{message_id: "msg123"}, "token")

    assert {:ok, %{deleted?: true, message_ids: ["msg123", "msg456"]}} =
             Client.batch_delete_messages(%{message_ids: ["msg123", "msg456"]}, "token")
  end

  test "handles Gmail thread lifecycle endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"POST", "/gmail/v1/users/me/threads/thread123/modify"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "addLabelIds" => ["Label_123"],
                   "removeLabelIds" => ["UNREAD"]
                 }

          Req.Test.json(conn, %{
            "id" => "thread123",
            "historyId" => "456",
            "messages" => [
              %{"id" => "msg123", "threadId" => "thread123", "labelIds" => ["Label_123"]}
            ]
          })

        {"POST", "/gmail/v1/users/me/threads/thread123/trash"} ->
          Req.Test.json(conn, %{
            "id" => "thread123",
            "messages" => [
              %{"id" => "msg123", "threadId" => "thread123", "labelIds" => ["TRASH"]}
            ]
          })

        {"POST", "/gmail/v1/users/me/threads/thread123/untrash"} ->
          Req.Test.json(conn, %{
            "id" => "thread123",
            "messages" => [
              %{"id" => "msg123", "threadId" => "thread123", "labelIds" => ["INBOX"]}
            ]
          })

        {"DELETE", "/gmail/v1/users/me/threads/thread123"} ->
          Req.Test.json(conn, %{})
      end
    end)

    assert {:ok, %Thread{} = thread} =
             Client.modify_thread(
               %{
                 thread_id: "thread123",
                 add_label_ids: ["Label_123"],
                 remove_label_ids: ["UNREAD"]
               },
               "token"
             )

    assert thread.thread_id == "thread123"
    assert [%Message{label_ids: ["Label_123"]}] = thread.messages

    assert {:ok, %Thread{messages: [%Message{label_ids: ["TRASH"]}]}} =
             Client.trash_thread(%{thread_id: "thread123"}, "token")

    assert {:ok, %Thread{messages: [%Message{label_ids: ["INBOX"]}]}} =
             Client.untrash_thread(%{thread_id: "thread123"}, "token")

    assert {:ok, %{deleted?: true, thread_id: "thread123"}} =
             Client.delete_thread(%{thread_id: "thread123"}, "token")
  end

  test "handles Gmail label update and delete endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"PUT", "/gmail/v1/users/me/labels/Label_123"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "name" => "Customers VIP",
                   "messageListVisibility" => "show"
                 }

          Req.Test.json(conn, %{
            "id" => "Label_123",
            "name" => "Customers VIP",
            "type" => "user",
            "messageListVisibility" => "show"
          })

        {"DELETE", "/gmail/v1/users/me/labels/Label_123"} ->
          Req.Test.json(conn, %{})
      end
    end)

    assert {:ok, %Label{} = label} =
             Client.update_label(
               %{
                 label_id: "Label_123",
                 name: "Customers VIP",
                 message_list_visibility: "show"
               },
               "token"
             )

    assert label.name == "Customers VIP"

    assert {:ok, %{deleted?: true, label_id: "Label_123"}} =
             Client.delete_label(%{label_id: "Label_123"}, "token")
  end

  describe "content requests" do
    # The format=full bodies are responses recorded from the prepared messages
    # of the live test account; content_live_smoke_test.exs records them, and
    # discovery_live_smoke_test.exs records the error body.

    test "gets a message with format=full and without metadataHeaders" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_attached")
      message_id = recorded["id"]

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/gmail/v1/users/me/messages/#{message_id}"
        assert conn.query_params == %{"format" => "full"}
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

        Req.Test.json(conn, recorded)
      end)

      assert Client.get_message_content(%{message_id: message_id}, "token") == {:ok, recorded}
    end

    test "gets a thread with format=full and without metadataHeaders" do
      recorded = LiveSmoke.fixture!(:gmail, "thread_full_conversation")
      thread_id = recorded["id"]

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/gmail/v1/users/me/threads/#{thread_id}"
        assert conn.query_params == %{"format" => "full"}

        Req.Test.json(conn, recorded)
      end)

      assert Client.get_thread_content(%{thread_id: thread_id}, "token") == {:ok, recorded}
    end

    test "sends the message and thread ID as one encoded path segment" do
      message = LiveSmoke.fixture!(:gmail, "message_full_single_part")
      thread = LiveSmoke.fixture!(:gmail, "thread_full_conversation")

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/gmail/v1/users/me/messages/a%2Fb%20c%3F"
        Req.Test.json(conn, message)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/gmail/v1/users/me/threads/a%2Fb%20c%3F"
        Req.Test.json(conn, thread)
      end)

      assert {:ok, ^message} = Client.get_message_content(%{message_id: "a/b c?"}, "token")
      assert {:ok, ^thread} = Client.get_thread_content(%{thread_id: "a/b c?"}, "token")
    end

    test "returns provider errors for failed requests and success bodies that are not objects" do
      # Google answers every Gmail call with the same error envelope; this body
      # is the recorded rejection of a query search.
      %{"error" => %{"message" => message}} =
        rejection = LiveSmoke.fixture!(:gmail, "messages_list_query_metadata_scope")

      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(rejection)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "not a JSON object")
      end)

      assert {:error,
              %Jido.Connect.Error.ProviderError{
                provider: :google,
                status: 403,
                details: %{message: ^message}
              }} = Client.get_message_content(%{message_id: "msg"}, "token")

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
               Client.get_thread_content(%{thread_id: "thread"}, "token")
    end
  end
end
