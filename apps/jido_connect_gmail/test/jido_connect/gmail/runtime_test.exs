defmodule Jido.Connect.Gmail.RuntimeTest do
  @moduledoc """
  Polls `google.gmail.message.received` through `Jido.Connect.poll/4` and
  invokes `google.gmail.message.labels.apply` and `google.gmail.message.send`
  through `Jido.Connect.invoke/4` with the real Gmail client against
  `Req.Test`. The lease carries no `gmail_client`, and every answer is a
  response that `history_live_smoke_test.exs`, `labels_live_smoke_test.exs` or
  `send_live_smoke_test.exs` recorded from the Google Workspace test account.
  """

  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Gmail
  alias Jido.Connect.TestSupport.LiveSmoke

  @history_path "/gmail/v1/users/me/history"
  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"
  @send_scope "https://www.googleapis.com/auth/gmail.send"

  # A history ID before every recorded history record. The recordings keep
  # the request path without its query, so the checkpoints of the live runs
  # are not in them.
  @checkpoint "16000"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gmail, :gmail_api_base_url, "https://gmail.test")
    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_gmail, :gmail_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  describe "google.gmail.message.received" do
    # message_received_history is the live poll of an inserted message and a
    # reply to it, from the checkpoint the poll initialized before both.

    test "a reply that follows its original in one thread yields two signals with one thread ID" do
      page = LiveSmoke.fixture!(:gmail, "message_received_history")

      assert [
               %{
                 "messagesAdded" => [
                   %{"message" => %{"id" => original_id, "threadId" => thread_id}}
                 ]
               },
               %{
                 "messagesAdded" => [%{"message" => %{"id" => reply_id, "threadId" => thread_id}}]
               }
             ] = page["history"]

      assert original_id != reply_id

      expect_history(page, fn _query -> :ok end)

      assert {:ok, %{signals: [original, reply], checkpoint: checkpoint}} =
               poll(%{}, @checkpoint)

      assert {original.message_id, original.thread_id} == {original_id, thread_id}
      assert {reply.message_id, reply.thread_id} == {reply_id, thread_id}
      assert checkpoint == page["historyId"]
    end

    test "label_id \"\" sends the checkpoint and messageAdded without labelId, the default sends labelId=INBOX" do
      page = LiveSmoke.fixture!(:gmail, "message_received_history")

      expect_history(page, fn query ->
        assert query == [
                 {"historyTypes", "messageAdded"},
                 {"maxResults", "100"},
                 {"startHistoryId", @checkpoint}
               ]
      end)

      expect_history(page, fn query ->
        assert query == [
                 {"historyTypes", "messageAdded"},
                 {"labelId", "INBOX"},
                 {"maxResults", "100"},
                 {"startHistoryId", @checkpoint}
               ]
      end)

      assert {:ok, %{signals: [_original, _reply]}} = poll(%{label_id: ""}, @checkpoint)
      assert {:ok, %{signals: [_original, _reply]}} = poll(%{}, @checkpoint)
    end

    test "a recorded Google error for the nextPageToken request fails the poll instead of returning the first page" do
      # The first page holds one of two records and a nextPageToken. The error
      # is Google's answer to a history request with a page token it never
      # issued.
      %{"history" => [_record], "nextPageToken" => page_token} =
        first = LiveSmoke.fixture!(:gmail, "message_received_history_first_page")

      %{"status" => status, "body" => %{"error" => %{"message" => message}} = rejection} =
        recording!("message_received_history_invalid_page_token")

      expect_history(first, fn query ->
        assert {"maxResults", "1"} in query
        refute List.keymember?(query, "pageToken", 0)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.request_path} == {"GET", @history_path}
        assert conn.query_params["pageToken"] == page_token
        assert conn.query_params["startHistoryId"] == @checkpoint

        conn
        |> Plug.Conn.put_status(status)
        |> Req.Test.json(rejection)
      end)

      assert {:error,
              %ProviderError{provider: :google, status: ^status, details: %{message: ^message}} =
                error} = poll(%{page_size: 1}, @checkpoint)

      refute error.reason == :checkpoint_expired
    end

    test "sparse messagesAdded entries yield signals without snippet, internal_date and size_estimate" do
      page = LiveSmoke.fixture!(:gmail, "message_received_history")
      records = page["history"]

      for %{"messagesAdded" => added} <- records, %{"message" => message} <- added do
        assert message |> Map.keys() |> Enum.sort() == ["id", "labelIds", "threadId"]
      end

      expect_history(page, fn _query -> :ok end)

      assert {:ok, %{signals: signals}} = poll(%{}, @checkpoint)
      assert length(signals) == length(records)

      for {signal, %{"id" => history_id, "messagesAdded" => [%{"message" => message}]}} <-
            Enum.zip(signals, records) do
        assert signal.message_id == message["id"]
        assert signal.thread_id == message["threadId"]
        assert signal.label_ids == message["labelIds"]
        assert signal.history_id == history_id

        # The signal leaves the content fields out. The nested message
        # carries no value for them, whether it keeps the keys or not.
        for key <- [:snippet, :internal_date, :size_estimate] do
          refute Map.has_key?(signal, key)
          assert Map.get(signal.message, key) == nil
        end
      end
    end
  end

  describe "google.gmail.message.labels.apply" do
    test "archiving sends one modify request that removes INBOX and touches no thread, Trash or delete endpoint" do
      %{"request" => %{"method" => "POST", "path" => path}, "body" => archived} =
        recording!("message_modify_archive")

      %{"id" => message_id, "threadId" => thread_id, "labelIds" => label_ids} = archived
      assert path == "/gmail/v1/users/me/messages/#{message_id}/modify"
      test_pid = self()

      # Every request other than the one modify request fails, among them
      # threads/ requests, /trash and DELETE.
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:gmail_request, conn.method, conn.request_path, body})

        case {conn.method, conn.request_path} do
          {"POST", ^path} -> Req.Test.json(conn, archived)
          {method, request_path} -> flunk("labels.apply sent #{method} #{request_path}")
        end
      end)

      assert {:ok, %{message: %{message_id: ^message_id, thread_id: ^thread_id} = message}} =
               invoke_labels_apply(%{
                 message_id: message_id,
                 add_label_ids: [],
                 remove_label_ids: ["INBOX"]
               })

      assert message.label_ids == label_ids
      refute "INBOX" in message.label_ids

      assert_received {:gmail_request, "POST", ^path, body}
      assert Jason.decode!(body) == %{"addLabelIds" => [], "removeLabelIds" => ["INBOX"]}
      refute_received {:gmail_request, _method, _path, _body}
    end

    test "a recorded 404 for an unknown message ID returns the provider error" do
      # The ID of a message the live test deleted for good before the request.
      %{"request" => %{"method" => "POST", "path" => path}, "status" => 404, "body" => rejection} =
        recording!("message_modify_unknown_id")

      ["/", "gmail", "v1", "users", "me", "messages", message_id, "modify"] = Path.split(path)

      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.request_path} == {"POST", path}

        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(rejection)
      end)

      assert {:error, %ProviderError{provider: :google, status: 404}} =
               invoke_labels_apply(%{
                 message_id: message_id,
                 add_label_ids: [],
                 remove_label_ids: ["INBOX"]
               })
    end
  end

  describe "google.gmail.message.send" do
    # message_send_reply is Gmail's answer to the reply that
    # send_live_smoke_test.exs sends in the thread of its first mail.

    test "a reply carries In-Reply-To and References in raw and the thread ID beside it" do
      %{"request" => request, "body" => sent} = recording!("message_send_reply")
      %{"id" => reply_id, "threadId" => thread_id} = sent
      original_header_id = "<original-1@example.org>"

      Req.Test.expect(__MODULE__, fn conn ->
        assert %{"method" => conn.method, "path" => conn.request_path} == request
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"raw" => raw, "threadId" => ^thread_id} = body = Jason.decode!(body)
        assert map_size(body) == 2

        assert [head, "Thanks."] =
                 raw |> Base.url_decode64!(padding: false) |> :binary.split("\r\n\r\n")

        lines = String.split(head, "\r\n")
        assert "Subject: Re: Hello" in lines
        assert "In-Reply-To: #{original_header_id}" in lines
        assert "References: #{original_header_id}" in lines
        Req.Test.json(conn, sent)
      end)

      assert {:ok, %{message: %{message_id: ^reply_id, thread_id: ^thread_id} = message}} =
               invoke_send(%{
                 to: ["to@example.com"],
                 subject: "Re: Hello",
                 body_text: "Thanks.",
                 thread_id: thread_id,
                 in_reply_to: original_header_id,
                 references: original_header_id
               })

      assert message.label_ids == ["SENT"]
    end
  end

  # A whole recording: the request, the status, the headers and the body.
  defp recording!(name) do
    ["test", "fixtures", "gmail", "recorded", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  # Expects one history.list request, checks its query, decoded and sorted,
  # with `check` and answers with `page`.
  defp expect_history(page, check) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert {conn.method, conn.request_path} == {"GET", @history_path}
      check.(conn.query_string |> URI.query_decoder() |> Enum.sort())
      Req.Test.json(conn, page)
    end)
  end

  defp poll(config, checkpoint) do
    {context, lease} = context_and_lease([@metadata_scope])

    Connect.poll(Gmail.integration(), "google.gmail.message.received", config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp invoke_labels_apply(input) do
    {context, lease} = context_and_lease([@modify_scope])

    Connect.invoke(Gmail.integration(), "google.gmail.message.labels.apply", input,
      context: context,
      credential_lease: lease
    )
  end

  defp invoke_send(input) do
    {context, lease} = context_and_lease([@send_scope])

    Connect.invoke(Gmail.integration(), "google.gmail.message.send", input,
      context: context,
      credential_lease: lease
    )
  end

  defp context_and_lease(scopes) do
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

    {context, lease}
  end
end
