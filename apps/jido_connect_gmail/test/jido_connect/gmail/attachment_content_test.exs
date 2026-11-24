defmodule Jido.Connect.Gmail.AttachmentContentTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.{AttachmentContent, Client}
  alias Jido.Connect.TestSupport.LiveSmoke

  # Runs Client.get_attachment_content/2 and google.gmail.message.attachment.content.get
  # against Req.Test. Every response body is recorded from the prepared
  # messages of the live test account; the `*_live_smoke_test.exs` files beside
  # this one record them. Gmail issues new attachment IDs with every response,
  # so the recordings named attachment_content_<name> hold a format=full
  # response and the attachments.get response for an attachment ID from it. A
  # test that needs a shape the recordings lack derives it from a recording and
  # says so. Each test expects exactly the requests it lists, so any further
  # request, such as a second attachment fetch, fails it.

  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gmail, :gmail_api_base_url, "https://gmail.test")

    Application.put_env(:jido_connect_google, :google_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_gmail, :gmail_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  # data.bin as the seed script builds it, and the SHA-256 from its manifest.
  @data_bin for i <- 0..4095, into: <<>>, do: <<rem(i * 31 + 7, 256)>>
  @data_bin_sha256 "d41d438c379110c7f7b2c561b1f04f26c1b4549110791f8e022f48974280c13e"

  describe "external attachments" do
    test "an external attachment causes one format=full and one attachments request" do
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")

      # The attachments request uses the attachment ID of the same response.
      assert find_part(full["payload"], "4")["body"]["attachmentId"] == attachment_id(fetch)

      expect_full(full)
      expect_attachment(fetch)

      assert {:ok, %AttachmentContent{} = content} = get(full["id"], "4")

      assert Map.from_struct(%{content | data: :checked}) == %{
               message_id: full["id"],
               thread_id: full["threadId"],
               history_id: full["historyId"],
               part_id: "4",
               attachment_id: attachment_id(fetch),
               filename: "data.bin",
               mime_type: "application/octet-stream",
               size: 4096,
               disposition: "attachment",
               content_id: nil,
               data: :checked,
               metadata: %{}
             }

      # Binary data beyond 512 bytes, byte-exact, as Gmail sent it.
      assert content.data == fetch["body"]["data"]
      bytes = Base.url_decode64!(content.data)
      assert bytes == @data_bin
      assert sha256(bytes) == @data_bin_sha256
    end

    test "of two attachments with the same filename only the selected one loads" do
      %{"body" => full} = recording!("attachment_content_report_csv")
      fetch = recording!("attachment_content_report_csv.2")
      first_id = find_part(full["payload"], "6")["body"]["attachmentId"]
      second_id = find_part(full["payload"], "7")["body"]["attachmentId"]

      assert attachment_id(fetch) == second_id
      refute first_id == second_id

      expect_full(full)
      expect_attachment(fetch)

      assert {:ok, %AttachmentContent{} = content} = get(full["id"], "7")

      assert %{part_id: "7", filename: "report.csv", size: 23, attachment_id: ^second_id} =
               content

      assert Base.url_decode64!(content.data) == "id,name\n2,beta\n3,gamma\n"
    end

    test "an attachment in the multipart/mixed part of an enclosed message" do
      %{"body" => full} = recording!("attachment_content_forward_inner")
      fetch = recording!("attachment_content_forward_inner.2")

      expect_full(full)
      expect_attachment(fetch)

      assert {:ok,
              %AttachmentContent{part_id: "1.0.1", filename: "inner.txt", size: 19} = content} =
               get(full["id"], "1.0.1")

      assert Base.url_decode64!(content.data) == "Inner attachment.\r\n"
    end

    test "an enclosed message behind an attachmentId returns the whole original" do
      %{"body" => full} = recording!("attachment_content_headers_only")
      fetch = recording!("attachment_content_headers_only.2")

      expect_full(full)
      expect_attachment(fetch)

      assert {:ok,
              %AttachmentContent{
                part_id: "2",
                filename: "headers-only.eml",
                mime_type: "message/rfc822",
                size: 258
              } = content} = get(full["id"], "2")

      original = Base.url_decode64!(content.data)
      assert byte_size(original) == 258
      assert String.starts_with?(original, "From: Opaque Sender <opaque.sender@example.org>\r\n")
      assert original =~ "\r\nSubject: jcl-live headers-only original\r\n"
    end

    test "Gmail's padded data and the same data unpadded round-trip byte-exact" do
      # Gmail pads data; the unpadded variant strips that padding from the
      # recorded attachments.get response.
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")
      padded = fetch["body"]["data"]
      unpadded = String.trim_trailing(padded, "=")
      refute unpadded == padded

      for data <- [padded, unpadded] do
        expect_full(full)
        expect_attachment(put_in(fetch, ["body", "data"], data))

        assert {:ok, %AttachmentContent{data: ^data}} = get(full["id"], "4")
        assert Base.url_decode64!(data, padding: false) == @data_bin
      end
    end

    test "invalid base64url and a size mismatch fail without the data" do
      # Variants: the recorded data with a character outside the base64url
      # alphabet, and the recorded format=full response with body.size 4095.
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")
      data = fetch["body"]["data"]

      expect_full(full)
      expect_attachment(put_in(fetch, ["body", "data"], "*" <> data))

      assert {:error,
              %Connect.Error.ProviderError{reason: :invalid_base64url, details: %{part_id: "4"}} =
                error} = get(full["id"], "4")

      refute inspect(error) =~ data

      expect_full(full, update_part(full, "4", &put_in(&1, ["body", "size"], 4095)))
      expect_attachment(fetch)

      assert {:error,
              %Connect.Error.ProviderError{
                provider: :google,
                reason: :attachment_size_mismatch,
                details: details
              } = error} = get(full["id"], "4")

      assert details == %{part_id: "4"}
      refute inspect(error) =~ data
    end

    test "sends message and attachment IDs as single encoded path segments" do
      # A variant of the recorded pair under a message ID and an attachment ID
      # that need percent-encoding.
      %{"body" => full} = recording!("attachment_content_data_bin")
      %{"body" => fetched} = recording!("attachment_content_data_bin.2")

      variant =
        %{full | "id" => "a/b c?"}
        |> update_part("4", &put_in(&1, ["body", "attachmentId"], "x/y+z="))

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/gmail/v1/users/me/messages/a%2Fb%20c%3F"
        Req.Test.json(conn, variant)
      end)

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path ==
                 "/gmail/v1/users/me/messages/a%2Fb%20c%3F/attachments/x%2Fy%2Bz%3D"

        assert conn.query_params == %{}
        Req.Test.json(conn, fetched)
      end)

      assert {:ok, %AttachmentContent{message_id: "a/b c?", attachment_id: "x/y+z="}} =
               get("a/b c?", "4")
    end

    test "a failed attachments request fails the read" do
      # The recorded pair, with the attachments request answered by the
      # recorded rejection of an unknown attachment ID.
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")
      rejection = recording!("attachment_unknown_id")

      expect_full(full)
      expect_attachment(%{rejection | "request" => fetch["request"]})

      assert {:error,
              %Connect.Error.ProviderError{
                provider: :google,
                status: 400,
                details: %{message: "Invalid attachment token"}
              }} = get(full["id"], "4")
    end

    test "an attachments response without data is an invalid response" do
      # The recorded attachments.get response without its data field.
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")

      expect_full(full)
      expect_attachment(update_in(fetch, ["body"], &Map.delete(&1, "data")))

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_response, details: details}} =
               get(full["id"], "4")

      assert details == %{message_id: full["id"], part_id: "4"}
    end
  end

  describe "inline attachments" do
    test "an inline attachment causes the format=full request and no attachments request" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_attachments")
      expect_full(recorded)

      assert {:ok, %AttachmentContent{} = content} = get(recorded["id"], "5")

      assert Map.from_struct(content) == %{
               message_id: recorded["id"],
               thread_id: recorded["threadId"],
               history_id: recorded["historyId"],
               part_id: "5",
               attachment_id: nil,
               filename: "empty.bin",
               mime_type: "application/octet-stream",
               size: 0,
               disposition: "attachment",
               content_id: nil,
               data: "",
               metadata: %{}
             }
    end

    test "an enclosed message that Gmail returns inline is selectable by part ID" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_forward_opaque")
      expect_full(recorded)

      assert {:ok,
              %AttachmentContent{
                part_id: "1",
                filename: "empty.eml",
                mime_type: "message/rfc822",
                size: 0,
                attachment_id: nil,
                data: ""
              }} = get(recorded["id"], "1")
    end

    test "returns inline text that Gmail's conversion left unchanged" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_unnamed_attachments")

      for {part_id, text} <- [
            {"8", "Grüße in UTF-8, marker jcl-marker-unnamed-utf8.\n"},
            {"9", "id;name\n1;Mueller\n2;Weiss\n"}
          ] do
        expect_full(recorded)

        assert {:ok, %AttachmentContent{part_id: ^part_id, filename: nil, data: data} = content} =
                 get(recorded["id"], part_id)

        assert Base.url_decode64!(data, padding: false) == text
        assert content.size == byte_size(text)
      end
    end

    test "inline text that Gmail converted to UTF-8 fails without an attachments request" do
      # Parts 1, 3 and 5 are ISO-8859-1 and Windows-1252 text, part 6 UTF-16LE
      # text whose UTF-8 form keeps its 8 bytes.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_unnamed_attachments")

      for part_id <- ~w(1 3 5 6) do
        expect_full(recorded)

        assert {:error,
                %Connect.Error.ProviderError{
                  provider: :google,
                  reason: :attachment_converted,
                  details: %{part_id: ^part_id}
                } = error} = get(recorded["id"], part_id)

        refute inspect(error) =~ find_part(recorded["payload"], part_id)["body"]["data"]
      end
    end
  end

  describe "parts that are no attachment" do
    test "an unknown part ID, body text and a container fail without an invented attachment ID" do
      recorded = LiveSmoke.fixture!(:gmail, "message_full_attachments")

      for {part_id, reason} <- [
            {"8", :unknown_part_id},
            {"0.0.0", :not_an_attachment},
            {"0", :not_an_attachment}
          ] do
        expect_full(recorded)

        assert {:error, %Connect.Error.ValidationError{reason: ^reason, details: details} = error} =
                 get(recorded["id"], part_id)

        assert details == %{part_id: part_id}
        refute inspect(error) =~ "jcl-marker"
      end
    end

    test "a part with neither data nor an attachment ID fails without an attachments request" do
      # Gmail sends one of the two; this variant drops the attachmentId of
      # data.bin from the recorded body.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_attachments")

      expect_full(
        recorded,
        update_part(
          recorded,
          "4",
          &update_in(&1, ["body"], fn body -> Map.delete(body, "attachmentId") end)
        )
      )

      assert {:error,
              %Connect.Error.ProviderError{
                reason: :attachment_data_missing,
                details: %{part_id: "4"} = details
              }} = get(recorded["id"], "4")

      refute Map.has_key?(details, :attachment_id)
    end
  end

  describe "requests and responses" do
    test "sends the message ID as one encoded path segment" do
      # A variant of the recorded message under a message ID that needs
      # percent-encoding.
      recorded = %{LiveSmoke.fixture!(:gmail, "message_full_attachments") | "id" => "a/b c?"}

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/gmail/v1/users/me/messages/a%2Fb%20c%3F"
        assert conn.query_params == %{"format" => "full"}
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
        Req.Test.json(conn, recorded)
      end)

      assert {:ok, %AttachmentContent{message_id: "a/b c?", part_id: "5"}} = get("a/b c?", "5")
    end

    test "returns provider errors for a failed format=full request and a body that is no object" do
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
              %Connect.Error.ProviderError{
                provider: :google,
                status: 403,
                details: %{message: ^message}
              }} = get("msg", "5")

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_response}} = get("msg", "5")
    end

    test "a message without an id or a payload is an invalid response" do
      # Variants of the recorded message without its id, with a threadId that
      # is no string, and without its payload.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_attachments")

      expect_full(recorded, Map.delete(recorded, "id"))

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_response, details: details}} =
               get(recorded["id"], "5")

      assert details == %{message_id: recorded["id"], part_id: "5"}

      expect_full(recorded, %{recorded | "threadId" => 42})

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_response, details: ^details}} =
               get(recorded["id"], "5")

      expect_full(recorded, Map.delete(recorded, "payload"))

      assert {:error, %Connect.Error.ProviderError{reason: :invalid_mime_payload}} =
               get(recorded["id"], "5")
    end
  end

  describe "google.gmail.message.attachment.content.get" do
    test "returns the client result as a map with the same identity and data" do
      unnamed = LiveSmoke.fixture!(:gmail, "message_full_unnamed_attachments")
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")

      for {recorded, part_id, fetches} <- [{unnamed, "8", []}, {full, "4", [fetch]}] do
        expect_full(recorded)
        Enum.each(fetches, &expect_attachment/1)
        assert {:ok, %AttachmentContent{} = content} = get(recorded["id"], part_id)

        expect_full(recorded)
        Enum.each(fetches, &expect_attachment/1)

        assert {:ok, %{attachment: attachment}} =
                 invoke(%{message_id: recorded["id"], part_id: part_id}, [@readonly_scope])

        assert attachment == Map.from_struct(content)
      end
    end

    test "keeps attachment bytes beyond 512 bytes out of logs and telemetry" do
      %{"body" => full} = recording!("attachment_content_data_bin")
      fetch = recording!("attachment_content_data_bin.2")
      expect_full(full)
      expect_attachment(fetch)

      test_pid = self()
      handler_id = "gmail-attachment-content-#{System.unique_integer([:positive])}"

      :telemetry.attach_many(
        handler_id,
        [[:jido, :connect, :invoke, :start], [:jido, :connect, :invoke, :stop]],
        fn event, _measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)
      Logger.put_process_level(self(), :debug)

      log =
        ExUnit.CaptureLog.capture_log([level: :debug], fn ->
          assert {:ok, %{attachment: %{size: 4096, data: data}}} =
                   invoke(%{message_id: full["id"], part_id: "4"}, [@readonly_scope])

          send(test_pid, {:data, data})
        end)

      assert_received {:data, data}
      assert Base.url_decode64!(data) == @data_bin

      # A 64-character slice of the encoded bytes would show any copy of them.
      probe = binary_part(data, 1024, 64)
      refute log =~ probe

      assert_received {:telemetry, [:jido, :connect, :invoke, :stop], metadata}
      refute inspect(metadata, limit: :infinity, printable_limit: :infinity) =~ probe
    end

    test "passes Gmail's empty root part ID through to the lookup" do
      # The root of the single-part message is body text, so the lookup
      # rejects it; a root attachment would be selected by the same ID.
      recorded = LiveSmoke.fixture!(:gmail, "message_full_single_part")
      expect_full(recorded)

      assert {:error,
              %Connect.Error.ValidationError{reason: :not_an_attachment, details: %{part_id: ""}}} =
               invoke(%{message_id: recorded["id"], part_id: ""}, [@readonly_scope])
    end

    test "a metadata-only grant fails before any request" do
      assert {:error,
              %Connect.Error.AuthError{
                reason: :missing_scopes,
                missing_scopes: [@readonly_scope]
              }} = invoke(%{message_id: "msg", part_id: "1"}, [@metadata_scope])
    end

    test "a blank message ID or a part ID that is no string fails before any request" do
      for {input, field} <- [
            {%{message_id: " ", part_id: "1"}, :message_id},
            {%{message_id: "msg", part_id: 1}, :part_id}
          ] do
        assert {:error, %Connect.Error.ValidationError{} = error} =
                 invoke(input, [@readonly_scope])

        assert inspect(error) =~ Atom.to_string(field)
      end
    end
  end

  defp invoke(input, scopes) do
    {context, lease} = context_and_lease(scopes)

    Connect.invoke(Gmail.integration(), "google.gmail.message.attachment.content.get", input,
      context: context,
      credential_lease: lease
    )
  end

  defp get(message_id, part_id),
    do: Client.get_attachment_content(%{message_id: message_id, part_id: part_id}, "token")

  defp expect_full(%{"id" => id} = recorded, body \\ nil) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/gmail/v1/users/me/messages/#{id}"
      assert conn.query_params == %{"format" => "full"}

      Req.Test.json(conn, body || recorded)
    end)
  end

  defp expect_attachment(%{"request" => %{"path" => path}, "status" => status, "body" => body}) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == path
      assert conn.query_params == %{}

      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(body)
    end)
  end

  # A whole recording: the request, the status and the body.
  defp recording!(name) do
    ["test", "fixtures", "gmail", "recorded", "#{name}.json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp attachment_id(%{"request" => %{"path" => path}}),
    do: path |> String.split("/attachments/") |> List.last()

  defp sha256(bytes), do: :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp find_part(%{"partId" => part_id} = part, part_id), do: part

  defp find_part(part, part_id),
    do: Enum.find_value(Map.get(part, "parts", []), &find_part(&1, part_id))

  # Applies `fun` to the part with `part_id`, at any depth.
  defp update_part(recorded, part_id, fun),
    do: Map.update!(recorded, "payload", &map_part(&1, part_id, fun))

  defp map_part(%{"partId" => part_id} = part, part_id, fun), do: fun.(part)

  defp map_part(%{"parts" => parts} = part, part_id, fun),
    do: %{part | "parts" => Enum.map(parts, &map_part(&1, part_id, fun))}

  defp map_part(part, _part_id, _fun), do: part

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
