defmodule Jido.Connect.Gmail.ContentClientForwardsLiveSmokeTest do
  @moduledoc """
  Live checks of forwards that Outlook Web and Gmail Web built, inline and as
  attachment, read through `google.gmail.message.content.get`,
  `google.gmail.message.attachment.content.get` and
  `google.gmail.message.attachment.get`.

      mix test --only live_smoke

  The four messages are real mail: they carry a person's name, signature,
  addresses and images. The tests therefore record nothing, also when the run
  sets `JIDO_CONNECT_RECORD=1`: a live test records only through
  `LiveGmail.record/1`, which this module never calls. They look at text only
  for the marker lines, the `JCL Quelle` subject and generic signs of correct
  decoding: a non-ASCII letter is present, and neither U+FFFD nor `Ã` or `Â`
  appears, the first character of a two-byte UTF-8 sequence read as Latin-1
  or Windows-1252. Every assertion is a condition with a message that names
  the forward and the check, so a failure never prints message content.

  The inline forwards must return their text and no nested message; the
  Outlook inline forward carries neither a comment line nor a quoted
  original. The attached forwards must return the comment line in the outer
  text and exactly one nested message, the client's inline forward, with its
  text and with the part ID, `From`, `Date` and `Subject` that Gmail parsed
  for the enclosed message; the tests read Gmail's parse with a direct
  `messages.get` outside the connector and the recorder. Every forward lists
  `test.txt`, inside the nested message for the attached ones, and
  `google.gmail.message.attachment.content.get` must return the same bytes for
  it as `google.gmail.message.attachment.get`.

  The tests read `GOOGLE_ACCESS_TOKEN`,
  `GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_INLINE_ID`,
  `GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_ATTACHED_ID`,
  `GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_INLINE_ID` and
  `GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_ATTACHED_ID`; see
  `docs/live_smoke_tests.md` for the variables.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.TestSupport.LiveGmail

  # A UTF-8 sequence read as Latin-1 or Windows-1252 starts with one of these
  # for the letters and symbols of German text; U+FFFD replaces bytes that
  # were not decoded at all.
  @misdecoded ["\u{FFFD}", "Ã", "Â"]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_INLINE_ID"])
  test "Outlook Web inline forward: decoded text, no nested message, test.txt", %{env: env} do
    forward = "Outlook inline forward"
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_INLINE_ID"]
    message = content!(forward, message_id, access_token)

    assert subject_names_source?(message.subject), "#{forward}: subject names JCL Quelle"
    assert message.messages == [], "#{forward}: no nested message"
    assert_decoded_text(forward, message.text_parts)
    assert_test_file(forward, message_id, message.attachments, access_token)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_INLINE_ID"])
  test "Gmail Web inline forward: comment line, quoted subject, decoded text, test.txt",
       %{env: env} do
    forward = "Gmail inline forward"
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_INLINE_ID"]
    message = content!(forward, message_id, access_token)

    assert message.messages == [], "#{forward}: no nested message"
    assert_decoded_text(forward, message.text_parts)
    assert_text_holds(forward, message.text_parts, "Kommentar Gmail inline")
    assert_text_holds(forward, message.text_parts, "JCL Quelle")
    assert_test_file(forward, message_id, message.attachments, access_token)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_ATTACHED_ID"])
  test "Outlook Web attached forward: comment line and one nested message with test.txt",
       %{env: env} do
    forward = "Outlook attached forward"
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_ATTACHED_ID"]
    message = content!(forward, message_id, access_token)

    assert subject_names_source?(message.subject), "#{forward}: subject names JCL Quelle"
    assert_text_holds(forward, message.text_parts, "Kommentar Outlook Anlage")
    assert_no_misdecoding(forward, message.text_parts)

    nested = single_nested_message!(forward, message_id, message, access_token)
    assert_test_file("#{forward}, nested message", message_id, nested.attachments, access_token)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_ATTACHED_ID"])
  test "Gmail Web attached forward: no subject, comment line and one nested message with test.txt",
       %{env: env} do
    forward = "Gmail attached forward"
    access_token = env["GOOGLE_ACCESS_TOKEN"]
    message_id = env["GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_ATTACHED_ID"]
    message = content!(forward, message_id, access_token)

    assert message.subject in [nil, ""], "#{forward}: the outer message has no subject"
    assert_text_holds(forward, message.text_parts, "Kommentar Gmail Anhang")
    assert_no_misdecoding(forward, message.text_parts)

    nested = single_nested_message!(forward, message_id, message, access_token)
    assert_test_file("#{forward}, nested message", message_id, nested.attachments, access_token)
  end

  defp content!(forward, message_id, access_token) do
    case invoke(access_token, "google.gmail.message.content.get", %{message_id: message_id}) do
      {:ok, %{message: message}} -> message
      result -> flunk("#{forward}: message.content.get failed: #{failure(result)}")
    end
  end

  # The nested message is the client's inline forward: its part ID and its
  # From, Date and Subject are those of Gmail's own parse, its text decodes.
  defp single_nested_message!(forward, message_id, message, access_token) do
    assert length(message.messages) == 1, "#{forward}: exactly one nested message"
    [nested] = message.messages
    {part_id, gmail_headers} = gmail_enclosed_message!(forward, message_id, access_token)

    assert nested.part_id == part_id, "#{forward}: nested part ID matches Gmail's parse"

    for name <- ["From", "Date", "Subject"] do
      value = header(nested, name)
      assert is_binary(value) and value != "", "#{forward}: nested message has a #{name} header"

      assert value == gmail_header(gmail_headers, name),
             "#{forward}: nested #{name} matches Gmail's parse"
    end

    assert subject_names_source?(header(nested, "Subject")),
           "#{forward}: nested subject names JCL Quelle"

    assert_decoded_text("#{forward}, nested message", nested.text_parts)
    nested
  end

  # Gmail's parse of the forward, read with messages.get outside the
  # connector and the recorder: the part ID of its single message/rfc822 part
  # and the headers of the enclosed message, the root part inside it.
  defp gmail_enclosed_message!(forward, message_id, access_token) do
    case LiveGmail.gmail_api(:get, "/messages/#{message_id}", access_token,
           params: [format: "full"]
         ) do
      %{status: 200, body: %{"payload" => payload}} ->
        parts = rfc822_parts(payload)
        assert length(parts) == 1, "#{forward}: Gmail returns one message/rfc822 part"
        [part] = parts
        roots = Map.get(part, "parts")
        assert match?([%{} | _], roots), "#{forward}: Gmail parses the enclosed message"
        [root | _rest] = roots
        {Map.get(part, "partId"), Map.get(root, "headers")}

      %{status: status} ->
        flunk("#{forward}: messages.get format=full returned no payload, HTTP #{status}")
    end
  end

  # The message/rfc822 parts outside any other, in part order, as the
  # connector lists nested messages.
  defp rfc822_parts(%{"mimeType" => "message/rfc822"} = part), do: [part]

  defp rfc822_parts(%{"parts" => parts}) when is_list(parts),
    do: Enum.flat_map(parts, &rfc822_parts/1)

  defp rfc822_parts(_part), do: []

  # Plain text and HTML both arrive decoded, the plain text holds a non-ASCII
  # letter, and no text part shows a sign of wrong decoding. Outlook writes
  # its HTML letters as entities, so only the plain text must hold one.
  defp assert_decoded_text(forward, text_parts) do
    types = Enum.map(text_parts, & &1.mime_type)
    assert "text/plain" in types, "#{forward}: text has a text/plain part"
    assert "text/html" in types, "#{forward}: text has a text/html part"
    assert_no_misdecoding(forward, text_parts)

    assert text_parts
           |> Enum.filter(&(&1.mime_type == "text/plain"))
           |> Enum.all?(&non_ascii_letter?(&1.content)),
           "#{forward}: plain text holds a non-ASCII letter"
  end

  defp assert_no_misdecoding(forward, text_parts) do
    assert text_parts != [], "#{forward}: has text parts"

    for part <- text_parts do
      assert part.decoded == true and is_binary(part.content),
             "#{forward}: text part #{part.part_id} is decoded"

      refute String.contains?(part.content, @misdecoded),
             "#{forward}: text part #{part.part_id} shows no U+FFFD or UTF-8 read as Latin-1"
    end
  end

  defp assert_text_holds(forward, text_parts, line) do
    for mime_type <- ["text/plain", "text/html"] do
      assert Enum.any?(
               text_parts,
               &(&1.mime_type == mime_type and is_binary(&1.content) and
                   String.contains?(&1.content, line))
             ),
             "#{forward}: #{mime_type} holds #{line}"
    end
  end

  # test.txt is listed once; attachment.content.get by part ID returns its
  # declared size, and the same bytes as attachment.get by attachment ID.
  defp assert_test_file(forward, message_id, attachments, access_token) do
    entries = Enum.filter(attachments, &(&1.filename == "test.txt"))
    assert length(entries) == 1, "#{forward}: the manifest lists test.txt once"
    [entry] = entries
    assert is_binary(entry.attachment_id), "#{forward}: test.txt has an attachment ID"

    by_part =
      attachment_bytes!(
        forward,
        access_token,
        "google.gmail.message.attachment.content.get",
        %{message_id: message_id, part_id: entry.part_id}
      )

    by_id =
      attachment_bytes!(
        forward,
        access_token,
        "google.gmail.message.attachment.get",
        %{message_id: message_id, attachment_id: entry.attachment_id}
      )

    assert byte_size(by_part) == entry.size,
           "#{forward}: attachment.content.get returns the declared size of test.txt"

    assert LiveGmail.sha256(by_part) == LiveGmail.sha256(by_id),
           "#{forward}: test.txt has the same SHA-256 by part ID and by attachment ID"
  end

  defp attachment_bytes!(forward, access_token, action_id, input) do
    with {:ok, %{attachment: %{data: data}}} when is_binary(data) <-
           invoke(access_token, action_id, input),
         {:ok, bytes} <- Base.url_decode64(data, padding: false) do
      bytes
    else
      result -> flunk("#{forward}: #{action_id} failed for test.txt: #{failure(result)}")
    end
  end

  defp invoke(access_token, action_id, input) do
    {context, lease} = LiveGmail.read_grant(access_token)

    Connect.invoke(Gmail.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  # Names the error kind and reason, never a payload.
  defp failure({:error, error}) when is_struct(error),
    do: "#{inspect(error.__struct__)} #{inspect(Map.get(error, :reason))}"

  defp failure(:error), do: "data is not base64url"
  defp failure(_result), do: "unexpected result shape"

  defp subject_names_source?(subject),
    do: is_binary(subject) and String.contains?(subject, "JCL Quelle")

  defp non_ascii_letter?(text),
    do: is_binary(text) and Regex.match?(~r/(?=[^\x{00}-\x{7F}])\p{L}/u, text)

  defp header(%{headers: headers}, name) do
    Enum.find_value(headers, fn header -> if header.name == name, do: header.value end)
  end

  # A header as Gmail's messages.get returns it, `%{"name" => _, "value" => _}`.
  defp gmail_header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      %{"name" => ^name, "value" => value} -> value
      _header -> nil
    end)
  end

  defp gmail_header(_headers, _name), do: nil
end
