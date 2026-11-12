defmodule Jido.Connect.Gmail.MIMETest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Gmail.MIME

  test "builds base64url encoded text messages" do
    assert {:ok, raw} =
             MIME.build_raw(%{
               to: ["to@example.com"],
               cc: ["cc@example.com"],
               subject: "Hello",
               body_text: "Body"
             })

    assert {:ok, message} = Base.url_decode64(raw, padding: false)
    assert message =~ "To: to@example.com"
    assert message =~ "Cc: cc@example.com"
    assert message =~ "Subject: Hello"
    assert message =~ "Content-Type: text/plain; charset=UTF-8"
    assert message =~ "\r\n\r\nBody"
  end

  test "builds html messages" do
    assert {:ok, raw} =
             MIME.build_raw(%{
               to: ["to@example.com"],
               subject: "Hello",
               body_html: "<p>Body</p>"
             })

    assert {:ok, message} = Base.url_decode64(raw, padding: false)
    assert message =~ "Content-Type: text/html; charset=UTF-8"
    assert message =~ "<p>Body</p>"
  end

  describe "non-ASCII text" do
    # When the live test created a draft with a raw UTF-8 subject, Gmail
    # stored the subject garbled, so a non-ASCII subject goes out as RFC 2047
    # encoded words. The body keeps its UTF-8 bytes under the declared
    # charset.
    test "encodes the subject as UTF-8 B encoded words and keeps the body bytes" do
      assert {:ok, raw} =
               MIME.build_raw(%{
                 to: ["to@example.com"],
                 subject: "Grüße aus Köln",
                 body_text: "Grüße: äöü ÄÖÜ ß"
               })

      assert Base.url_decode64!(raw, padding: false) ==
               "To: to@example.com\r\n" <>
                 "Subject: =?UTF-8?B?R3LDvMOfZSBhdXMgS8O2bG4=?=\r\n" <>
                 "MIME-Version: 1.0\r\n" <>
                 "Content-Type: text/plain; charset=UTF-8\r\n" <>
                 "Content-Transfer-Encoding: 8bit\r\n" <>
                 "\r\n" <>
                 <<"Gr", 0xC3, 0xBC, 0xC3, 0x9F, "e: ", 0xC3, 0xA4, 0xC3, 0xB6, 0xC3, 0xBC, " ",
                   0xC3, 0x84, 0xC3, 0x96, 0xC3, 0x9C, " ", 0xC3, 0x9F>>
    end

    # One ASCII byte before 80 two-byte characters puts every character
    # boundary after the first at an odd offset, so a split every n bytes,
    # n up to 80, cuts a character at n or at 2n.
    test "folds a long subject into encoded words of whole characters and lines of at most 76" do
      subject = "x" <> String.duplicate("ä", 80)

      assert {:ok, raw} =
               MIME.build_raw(%{to: ["to@example.com"], subject: subject, body_text: "Body"})

      [first | continuations] = lines = subject_lines(raw)
      word = ~S"=\?UTF-8\?B\?[A-Za-z0-9+/=]+\?="
      assert first =~ ~r/\ASubject: #{word}\z/
      assert continuations != []
      assert Enum.all?(continuations, &(&1 =~ ~r/\A #{word}\z/))

      # RFC 2047, section 2: a header line that holds an encoded word is
      # limited to 76 characters.
      assert Enum.all?(lines, &(byte_size(&1) <= 76))

      decoded =
        for line <- lines,
            [data] <- Regex.scan(~r/=\?UTF-8\?B\?([^?]+)\?=/, line, capture: :all_but_first) do
          assert byte_size(data) + 12 <= 75
          Base.decode64!(data)
        end

      assert Enum.all?(decoded, &String.valid?/1)
      assert Enum.join(decoded) == subject
    end

    # 21 two-byte characters are 42 bytes. As one encoded word of 68
    # characters they would make a first line of 77 with "Subject: ". Words
    # of at most 39 bytes put 19 of them on a first line of 73 and 2 on a
    # continuation line of 21.
    test "splits 21 two-byte characters into two words so the first line stays within 76" do
      assert {:ok, raw} =
               MIME.build_raw(%{
                 to: ["to@example.com"],
                 subject: String.duplicate("ä", 21),
                 body_text: "Body"
               })

      assert subject_lines(raw) == [
               "Subject: =?UTF-8?B?w6TDpMOkw6TDpMOkw6TDpMOkw6TDpMOkw6TDpMOkw6TDpMOkw6Q=?=",
               " =?UTF-8?B?w6TDpA==?="
             ]
    end
  end

  # The Subject header of a raw message as a list of its lines, the first
  # starting with "Subject: " and each continuation line with a space.
  defp subject_lines(raw) do
    [_match, folded] =
      Regex.run(~r/\r\n(Subject: .*?)\r\n(?![ \t])/s, Base.url_decode64!(raw, padding: false))

    String.split(folded, "\r\n")
  end

  test "rejects invalid recipients" do
    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_recipient,
              details: %{field: :to}
            }} =
             MIME.build_raw(%{
               to: ["not-an-email"],
               subject: "Hello",
               body_text: "Body"
             })
  end

  test "requires message body" do
    assert {:error, %Connect.Error.ValidationError{reason: :missing_body}} =
             MIME.build_raw(%{to: ["to@example.com"], subject: "Hello"})
  end

  describe "header values" do
    @message %{to: ["to@example.com"], subject: "Hello", body_text: "Body"}

    test "a subject that carries a second header line is rejected" do
      assert {:error,
              %Connect.Error.ValidationError{
                reason: :invalid_header_value,
                details: %{field: :subject}
              } = error} = MIME.build_raw(%{@message | subject: "Hi\r\nBcc: x@example.com"})

      refute inspect(error) =~ "x@example.com"
    end

    # build_raw/1 is public and does not rely on the action schema, which
    # declares both threading fields as strings. Other values would reach the
    # header block through String.Chars, line breaks included.
    test "an in_reply_to or references that is not a string is rejected with the field" do
      injected = "<a@example.com>\r\nBcc: x@example.com"

      string_keys = %{
        "to" => ["to@example.com"],
        "subject" => "Hello",
        "body_text" => "Body",
        "references" => [injected]
      }

      for {field, input} <- [
            references: Map.put(@message, :references, [injected]),
            references:
              Map.put(@message, :references, ["<a@example.com>", ["\r\n", "Bcc: x@example.com"]]),
            references: string_keys,
            in_reply_to: Map.put(@message, :in_reply_to, [injected]),
            in_reply_to:
              Map.put(@message, :in_reply_to, ~c"<a@example.com>\r\nBcc: x@example.com"),
            in_reply_to:
              Map.put(@message, :in_reply_to, :"<a@example.com>\r\nBcc: x@example.com"),
            in_reply_to: Map.put(@message, :in_reply_to, 42)
          ] do
        assert {:error,
                %Connect.Error.ValidationError{
                  reason: :invalid_header_value,
                  details: %{field: ^field}
                } = error} = MIME.build_raw(input)

        refute inspect(error) =~ "x@example.com"
      end
    end

    test "a nil or empty in_reply_to or references leaves the header out" do
      for value <- [nil, ""] do
        input = Map.merge(@message, %{in_reply_to: value, references: value})
        assert {:ok, raw} = MIME.build_raw(input)
        assert {:ok, message} = Base.url_decode64(raw, padding: false)
        refute message =~ "In-Reply-To:"
        refute message =~ "References:"
      end
    end

    # The subject is trimmed before the check, the threading headers are not,
    # so a trailing break counts only in them.
    test "a bare CR or LF in subject, in_reply_to or references is rejected with the field" do
      for {field, value} <- [
            subject: "Hi\rthere",
            subject: "Hi\nthere",
            in_reply_to: "<a@example.com>\r<b@example.com>",
            in_reply_to: "<a@example.com>\n",
            references: "<a@example.com>\n<b@example.com>",
            references: "<a@example.com>\r"
          ] do
        assert {:error,
                %Connect.Error.ValidationError{
                  reason: :invalid_header_value,
                  details: %{field: ^field}
                }} = MIME.build_raw(Map.put(@message, field, value))
      end
    end

    test "a subject followed only by a line break is trimmed and accepted" do
      for subject <- ["Hello\n", "Hello\r\n"] do
        assert {:ok, raw} = MIME.build_raw(%{@message | subject: subject})
        assert {:ok, message} = Base.url_decode64(raw, padding: false)
        assert message =~ "\r\nSubject: Hello\r\nMIME-Version: 1.0\r\n"
      end
    end

    # Recipients are trimmed and must match the address pattern, which allows
    # no whitespace, so a break inside one fails there.
    test "a CR or LF inside a recipient is rejected as an invalid recipient" do
      for field <- [:to, :cc, :bcc],
          recipient <- [
            "a@example.com\r\nBcc: x@example.com",
            "a@example.com\rb@example.com",
            "a@example.com\nb@example.com"
          ] do
        assert {:error,
                %Connect.Error.ValidationError{
                  reason: :invalid_recipient,
                  details: %{field: ^field}
                }} = MIME.build_raw(Map.put(@message, field, [recipient]))
      end
    end
  end
end
