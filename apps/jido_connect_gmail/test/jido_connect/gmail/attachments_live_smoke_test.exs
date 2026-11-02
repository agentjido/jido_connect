defmodule Jido.Connect.Gmail.AttachmentsLiveSmokeTest do
  @moduledoc """
  Live checks of attachment content by MIME part against the prepared
  messages of the Google Workspace test account.

      mix test --only live_smoke

  `google.gmail.message.attachment.content.get` must return the exact bytes of
  every attachment of the prepared message, whether Gmail keeps them inline or
  behind an `attachmentId`. It must also return an attached original and an
  attachment inside it, the empty original inline and the header-only one, and
  unnamed attachments with their original bytes, and it must refuse the parts
  that Gmail converted to UTF-8 and a part that is no attachment.

  The tests read `GOOGLE_ACCESS_TOKEN`, `GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID`,
  `GOOGLE_GMAIL_FORWARD_ATTACHED_ID`, `GOOGLE_GMAIL_FORWARD_OPAQUE_ID` and
  `GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID`; see `docs/live_smoke_tests.md`
  for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Client
  alias Jido.Connect.Gmail.MIME.Traversal
  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  # google.gmail.message.attachment.content.get. Each test compares the bytes
  # with the files that the seed script built, by byte count and SHA-256 from
  # its manifest. A recording takes every later response of its test, so the
  # unrecorded calls come first. Each recorded call writes a format=full
  # response and, for data behind an attachmentId, the attachments.get
  # response for an ID from it, as attachment_content_<name>.json and .2.json.

  @attachment_files [
    {"0.1", "logo.png", 73, "805924e65dff89ccbac4046a6995a73622a878f5ff9ec17678b4bc33ca55ea12"},
    {"3", "notes.txt", 27, "f35e372236d8d39aec9fd80e718e92c8b1e8aa136907ba55b4411393a204187e"},
    {"4", "data.bin", 4096, "d41d438c379110c7f7b2c561b1f04f26c1b4549110791f8e022f48974280c13e"},
    {"5", "empty.bin", 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
    {"6", "report.csv", 16, "15a12746b2a7f4d887a8e1cf6c0d603c419a980b097d79e1aa13b0f613cc3984"},
    {"7", "report.csv", 23, "504c3f66763b328252c334fa6e3234a7469c526a02e79d4470d3c71abfd19fcf"}
  ]

  @recorded_attachments %{
    "4" => "attachment_content_data_bin",
    "7" => "attachment_content_report_csv"
  }

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"])
  test "attachment.content.get returns every attachment of the prepared message byte-exact",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID"]

    # Not recorded: message_full_attachments holds this response.
    assert {:ok, %{"payload" => payload}} =
             Client.get_message_content(%{message_id: message_id}, access_token)

    # The manifest lists exactly the known files; Gmail keeps empty.bin inline.
    assert {:ok, %{attachments: manifest}} = Traversal.traverse(payload)
    assert Enum.map(manifest, & &1.part_id) == Enum.map(@attachment_files, &elem(&1, 0))
    assert [%{part_id: "5"}] = Enum.filter(manifest, &is_nil(&1.attachment_id))

    {recorded, unrecorded} =
      Enum.split_with(@attachment_files, &Map.has_key?(@recorded_attachments, elem(&1, 0)))

    for {part_id, filename, size, sha256} <- unrecorded ++ recorded do
      case Map.fetch(@recorded_attachments, part_id) do
        {:ok, name} -> LiveGmail.record(name)
        :error -> :ok
      end

      attachment = attachment_content!(message_id, part_id, access_token)

      assert %{message_id: ^message_id, part_id: ^part_id, filename: ^filename, size: ^size} =
               attachment

      assert is_nil(attachment.attachment_id) == (part_id == "5")
      assert digest(attachment.data) == {size, sha256}
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_ATTACHED_ID"])
  test "attachment.content.get returns an attached original and an attachment inside it",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_FORWARD_ATTACHED_ID"]

    # Not recorded and compared by size only: the bytes of original.eml name
    # the real recipient in its To header.
    original = attachment_content!(message_id, "1", access_token)

    assert Map.take(original, [:part_id, :filename, :mime_type, :size]) ==
             %{part_id: "1", filename: "original.eml", mime_type: "message/rfc822", size: 1072}

    assert is_binary(original.attachment_id)
    assert byte_size(Base.url_decode64!(original.data, padding: false)) == 1072

    # inner.txt sits in the multipart/mixed part of the original.
    LiveGmail.record("attachment_content_forward_inner")

    inner = attachment_content!(message_id, "1.0.1", access_token)
    assert %{part_id: "1.0.1", filename: "inner.txt", size: 19} = inner

    assert digest(inner.data) ==
             {19, "82ba71b14a7df9e97396cfaab882b5934b0e70f0ac4011ce46e492d2bc141fd9"}
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_FORWARD_OPAQUE_ID"])
  test "attachment.content.get returns the empty original inline and the header-only one",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_FORWARD_OPAQUE_ID"]

    # Not recorded: message_full_forward_opaque holds this response.
    assert %{part_id: "1", filename: "empty.eml", size: 0, attachment_id: nil, data: ""} =
             attachment_content!(message_id, "1", access_token)

    # The header-only original names synthetic addresses only. The seed
    # manifest has no digest for it, so the bytes are compared with their
    # recording.
    LiveGmail.record("attachment_content_headers_only")

    headers_only = attachment_content!(message_id, "2", access_token)

    assert %{part_id: "2", filename: "headers-only.eml", mime_type: "message/rfc822", size: 258} =
             headers_only

    %{"data" => recorded} = LiveSmoke.fixture!(:gmail, "attachment_content_headers_only.2")
    assert digest(headers_only.data) == digest(recorded)
  end

  # The unnamed parts of GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID that Gmail
  # returns with their original bytes: the binary parts 2, 4 and 7 behind an
  # attachmentId, the UTF-8 part 8 and the ASCII-only ISO-8859-1 part 9 inline.
  @unnamed_files [
    {"2", 64, "c39e13bbb05726a3c0747d3ca54c27e3f86bc10a1d3754cd031bd1ca7256c8ed"},
    {"4", 73, "805924e65dff89ccbac4046a6995a73622a878f5ff9ec17678b4bc33ca55ea12"},
    {"7", 600, "9e1c936f1a61671484eed46c09637ce38afa0097dfee58c55926819db01a7d0a"},
    {"8", 50, "4b015575621b891b45221c6ee01374ac7c887b90829023af49423c99f29fba60"},
    {"9", 26, "242fd88425f231f1302026950fc51f8f904a6bbd198647b03aa6509a5194d12b"}
  ]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"])
  test "attachment.content.get returns unnamed attachments only with their original bytes",
       %{env: env} do
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID"]
    {context, lease} = LiveGmail.read_grant(access_token)

    # Not recorded: "traverses the unnamed-attachment message like its
    # recording" in content_live_smoke_test.exs records the format=full
    # response.
    for {part_id, size, sha256} <- @unnamed_files do
      attachment = attachment_content!(message_id, part_id, access_token)

      assert %{part_id: ^part_id, filename: nil, size: ^size} = attachment
      assert is_nil(attachment.attachment_id) == part_id in ["8", "9"]
      assert digest(attachment.data) == {size, sha256}
    end

    # Gmail returns the ISO-8859-1, Windows-1252 and UTF-16LE text inline and
    # converted to UTF-8; part 6 keeps its length.
    for part_id <- ["1", "3", "5", "6"] do
      assert {:error,
              %Connect.Error.ProviderError{
                reason: :attachment_converted,
                details: %{part_id: ^part_id}
              }} = invoke_attachment_content(message_id, part_id, context, lease)
    end

    assert {:error, %Connect.Error.ValidationError{reason: :not_an_attachment}} =
             invoke_attachment_content(message_id, "0", context, lease)
  end

  defp attachment_content!(message_id, part_id, access_token) do
    {context, lease} = LiveGmail.read_grant(access_token)

    assert {:ok, %{attachment: attachment}} =
             invoke_attachment_content(message_id, part_id, context, lease)

    attachment
  end

  defp invoke_attachment_content(message_id, part_id, context, lease) do
    Connect.invoke(
      Gmail.integration(),
      "google.gmail.message.attachment.content.get",
      %{message_id: message_id, part_id: part_id},
      context: context,
      credential_lease: lease
    )
  end

  defp digest(data) do
    bytes = Base.url_decode64!(data, padding: false)
    {byte_size(bytes), LiveGmail.sha256(bytes)}
  end
end
