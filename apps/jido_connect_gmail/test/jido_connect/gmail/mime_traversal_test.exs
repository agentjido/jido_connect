defmodule Jido.Connect.Gmail.MIME.TraversalTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Gmail.MIME.Traversal
  alias Jido.Connect.TestSupport.LiveSmoke

  # The payloads are format=full responses recorded from the prepared messages
  # of the live test account; live_smoke_test.exs records them and checks that
  # the live payloads still traverse the same way. A test that needs a shape
  # Gmail does not produce derives it from a recording and says so.

  describe "body text parts" do
    test "a single-part message is one text part with Gmail's empty part ID" do
      assert {:ok, traversal} = Traversal.traverse(payload("message_full_single_part"))

      assert traversal.text_parts == [
               %{
                 part_id: "",
                 mime_type: "text/plain",
                 charset: "utf-8",
                 size: 30,
                 content: "Archive pair message 1 of 2.\r\n",
                 content_base64: nil,
                 encoding: "utf-8",
                 decoded: true
               }
             ]

      assert traversal.attachments == []
      assert traversal.external_text_parts == []
      assert traversal.messages == []
    end

    test "nested mixed, related and alternative parts keep plain and HTML apart in part order" do
      # mixed > related > alternative (plain, HTML) + inline image, then two
      # inline text parts and six attachments.
      assert {:ok, traversal} = Traversal.traverse(payload("message_full_attachments"))

      assert Enum.map(traversal.text_parts, &{&1.part_id, &1.mime_type}) == [
               {"0.0.0", "text/plain"},
               {"0.0.1", "text/html"},
               {"1", "text/plain"},
               {"2", "text/plain"}
             ]

      assert Enum.map(traversal.attachments, & &1.part_id) == ~w(0.1 3 4 5 6 7)
    end

    test "a long text part decodes completely, without a byte cap" do
      [_first, _reply, long] = thread_payloads()

      assert {:ok, %{text_parts: [text]}} = Traversal.traverse(long)

      assert %{part_id: "0", size: 55_272, decoded: true} = text
      assert byte_size(text.content) == 55_272
      assert String.starts_with?(text.content, "Danke. Anbei die Notizen, Grüße.\r\n")
      assert String.ends_with?(text.content, "Marker jcl-marker-conv-long-end.\r\n")
    end

    test "a text part stored behind an attachmentId is listed for the caller to fetch" do
      # Gmail delivered even the 55 KB body inline, so no recording has a body
      # text part behind an attachmentId. This variant moves the attachmentId of
      # notiz.txt onto the long body part of the same recorded message.
      [_first, _reply, long] = thread_payloads()
      [body_part, notiz] = long["parts"]

      stored = %{
        body_part
        | "body" => %{"attachmentId" => notiz["body"]["attachmentId"], "size" => 55_272}
      }

      assert {:ok, traversal} = Traversal.traverse(%{long | "parts" => [stored, notiz]})

      assert traversal.text_parts == []

      assert traversal.external_text_parts == [
               %{
                 part_id: "0",
                 attachment_id: notiz["body"]["attachmentId"],
                 mime_type: "text/plain",
                 charset: "utf-8",
                 size: 55_272
               }
             ]

      assert [%{part_id: "1", filename: "notiz.txt"}] = traversal.attachments
    end
  end

  describe "charsets of format=full data" do
    # For format=full, Gmail converts the data of every text part to UTF-8 and
    # keeps the declared charset in the Content-Type header; body.size still
    # counts the original bytes. The recordings below show that for each listed
    # charset, for koi8-r and for bytes that are invalid UTF-8.

    test "each listed charset arrives as UTF-8 text under its declared charset" do
      attachments = traverse!(payload("message_full_attachments"))
      charsets = traverse!(payload("message_full_charsets"))
      conversation = traverse!(hd(thread_payloads()))

      assert text(conversation, "0") ==
               {"utf-8", true,
                "Hallo,\r\n\r\nkönnen wir den jcl-live Termin bestätigen?\r\n\r\nGruß\r\nJcl Recipient\r\n"}

      assert text(attachments, "0.0.0") ==
               {"iso-8859-1", true,
                "Grüße aus Köln. Maß, Größe, 5 °C, Preis 12,50 ¤.\r\nMarker jcl-marker-latin1.\r\n"}

      assert text(attachments, "0.0.1") ==
               {"windows-1252", true,
                "<p>“Zitat” – Preis 12 € – Grüße.</p><p><img src=\"cid:jcl-logo\" alt=\"logo\"></p>"}

      assert text(charsets, "0") ==
               {"iso-8859-15", true,
                "Latin-9: Preis 12 €, Œuvre, Šoba, Žeton, Ÿ, Grüße.\r\nMarker jcl-marker-latin9.\r\n"}

      assert text(charsets, "1") ==
               {"us-ascii", true,
                "Plain text with an explicit US-ASCII charset.\r\nMarker jcl-marker-ascii.\r\n"}
    end

    test "size counts the UTF-8 bytes returned, not Gmail's original body size" do
      payload = payload("message_full_attachments")
      latin1 = payload |> find_part("0.0.0") |> get_in(["body", "size"])

      assert latin1 == 77
      assert %{size: 85} = text_part(traverse!(payload), "0.0.0")
    end

    test "an absent charset is reported as US-ASCII" do
      assert text(traverse!(payload("message_full_attachments")), "1") ==
               {"us-ascii", true, "Part without a charset parameter.\r\n"}
    end

    test "Gmail also converts a charset outside the listed ones" do
      assert text(traverse!(payload("message_full_attachments")), "2") ==
               {"koi8-r", true, "Привет, это тест jcl-live.\n"}
    end

    test "Gmail replaces bytes that are invalid UTF-8 before the traversal sees them" do
      # The source part holds \xC3\x28, \xFF\xFE and \x80; Gmail returns them
      # read as Windows-1252.
      assert text(traverse!(payload("message_full_charsets")), "2") ==
               {"utf-8", true,
                "Declared UTF-8 with invalid bytes: Ã( ÿþ €.\nMarker jcl-marker-invalid-utf8.\n"}
    end

    test "data that is not UTF-8 keeps its bytes as standard base64 with decoded false" do
      # Gmail sends UTF-8 here; this variant puts the recorded Latin-1 text back
      # into its original bytes, as attachments.get would return them.
      payload = payload("message_full_attachments")
      %{content: text} = text_part(traverse!(payload), "0.0.0")
      latin1 = :unicode.characters_to_binary(text, :utf8, :latin1)

      variant =
        map_parts(payload, fn
          %{"partId" => "0.0.0"} = part ->
            update_data(part, fn _ -> Base.url_encode64(latin1) end)

          part ->
            part
        end)

      assert text_part(traverse!(variant), "0.0.0") == %{
               part_id: "0.0.0",
               mime_type: "text/plain",
               charset: "iso-8859-1",
               size: 77,
               content: nil,
               content_base64: Base.encode64(latin1),
               encoding: "base64",
               decoded: false
             }
    end
  end

  describe "text parts fetched from attachments.get" do
    # attachments.get returns the original bytes of a part, so the declared
    # charset applies; attachment_notes_latin9 records that for notes.txt. No
    # recording has a body text part behind an attachmentId. The attributes
    # below are derived, not recorded: the recorded format=full text of a part
    # re-encoded into its declared charset with Python's codecs, each as long
    # as Gmail's body.size for that part. The invalid UTF-8 input is the seeded
    # source of that part.
    @latin1 "R3L832UgYXVzIEv2bG4uIE1h3ywgR3L232UsIDUgsEMsIFByZWlzIDEyLDUwIKQuDQpNYXJrZXIgamNsLW1hcmtlci1sYXRpbjEuDQo="
    @windows_1252 "PHA-k1ppdGF0lCCWIFByZWlzIDEyIIAgliBHcvzfZS48L3A-PHA-PGltZyBzcmM9ImNpZDpqY2wtbG9nbyIgYWx0PSJsb2dvIj48L3A-"
    @latin9 "TGF0aW4tOTogUHJlaXMgMTIgpCwgvHV2cmUsIKZvYmEsILRldG9uLCC-LCBHcvzfZS4NCk1hcmtlciBqY2wtbWFya2VyLWxhdGluOS4NCg=="
    @koi8_r "8NLJ18XULCDc1M8g1MXT1CBqY2wtbGl2ZS4K"
    @invalid_utf8 "RGVjbGFyZWQgVVRGLTggd2l0aCBpbnZhbGlkIGJ5dGVzOiDDKCD__iCALgpNYXJrZXIgamNsLW1hcmtlci1pbnZhbGlkLXV0ZjguCg=="

    test "decodes the original ISO-8859-15 bytes that attachments.get returned" do
      # notes.txt is a named attachment, so the traversal lists it in the
      # manifest. Its recorded attachments.get response stands here for a body
      # text part behind an attachmentId, which no recording has.
      assert %{"data" => data, "size" => 27} =
               LiveSmoke.fixture!(:gmail, "attachment_notes_latin9")

      entry = %{part_id: "3", mime_type: "text/plain", charset: "iso-8859-15"}

      assert Traversal.decode_external_text_part(entry, data) ==
               {:ok,
                %{
                  part_id: "3",
                  mime_type: "text/plain",
                  charset: "iso-8859-15",
                  size: 27,
                  content: "Notizen: € Œ œ Š š Ž ž Ÿ.\r\n",
                  content_base64: nil,
                  encoding: "utf-8",
                  decoded: true
                }}
    end

    test "each listed charset decodes to the text Gmail returns for format=full" do
      attachments = traverse!(payload("message_full_attachments"))
      charsets = traverse!(payload("message_full_charsets"))
      conversation = traverse!(hd(thread_payloads()))

      for {traversal, part_id, data, gmail_size} <- [
            {conversation, "0", :as_recorded, 80},
            {attachments, "0.0.0", @latin1, 77},
            {attachments, "0.0.1", @windows_1252, 78},
            {charsets, "0", @latin9, 79},
            {charsets, "1", :as_recorded, 73},
            {attachments, "1", :as_recorded, 35}
          ] do
        inline = text_part(traversal, part_id)
        data = if data == :as_recorded, do: Base.url_encode64(inline.content), else: data

        assert Traversal.decode_external_text_part(external(inline), data) ==
                 {:ok, %{inline | size: gmail_size}}
      end
    end

    test "an unsupported charset and bytes invalid for their charset keep standard base64" do
      # The last two variants declare a charset the bytes do not fit: Latin-1
      # bytes as US-ASCII, and Windows-1252 bytes with the undefined byte 0x81.
      windows_1252 = Base.url_decode64!(@windows_1252) <> <<0x81>>

      for {charset, data} <- [
            {"koi8-r", @koi8_r},
            {"utf-8", @invalid_utf8},
            {"us-ascii", @latin1},
            {"windows-1252", Base.url_encode64(windows_1252)}
          ] do
        bytes = Base.url_decode64!(data)
        entry = %{part_id: "2", mime_type: "text/plain", charset: charset}

        assert Traversal.decode_external_text_part(entry, data) ==
                 {:ok,
                  %{
                    part_id: "2",
                    mime_type: "text/plain",
                    charset: charset,
                    size: byte_size(bytes),
                    content: nil,
                    content_base64: Base.encode64(bytes),
                    encoding: "base64",
                    decoded: false
                  }}
      end
    end

    test "every byte that Windows-1252 leaves undefined keeps the data undecoded" do
      # Variants of the derived Windows-1252 input with one undefined byte each.
      for byte <- [0x81, 0x8D, 0x8F, 0x90, 0x9D] do
        data = Base.url_encode64(Base.url_decode64!(@windows_1252) <> <<byte>>)
        entry = %{part_id: "0.0.1", mime_type: "text/html", charset: "windows-1252"}

        assert {:ok, %{decoded: false, content: nil, encoding: "base64"}} =
                 Traversal.decode_external_text_part(entry, data)
      end
    end

    test "charset names match without regard to case" do
      # Gmail's recordings declare lower-case charsets; these variants of the
      # charset message spell them in upper case.
      variant =
        map_parts(payload("message_full_charsets"), fn
          %{"partId" => "0"} = part ->
            put_header(part, "Content-Type", ~s(text/plain; CHARSET="ISO-8859-15"))

          %{"partId" => "1"} = part ->
            put_header(part, "Content-Type", ~s(text/plain; charset="US-ASCII"))

          %{"partId" => "2"} = part ->
            put_header(part, "Content-Type", ~s(text/plain; charset="UTF-8"))

          part ->
            part
        end)

      assert Enum.map(traverse!(variant).text_parts, &{&1.part_id, &1.charset, &1.decoded}) == [
               {"0", "iso-8859-15", true},
               {"1", "us-ascii", true},
               {"2", "utf-8", true}
             ]

      for {charset, data} <- [
            {"ISO-8859-15", @latin9},
            {"Windows-1252", @windows_1252},
            {"ISO-8859-1", @latin1}
          ] do
        entry = %{part_id: "0", mime_type: "text/plain", charset: charset}
        lower = %{entry | charset: String.downcase(charset)}

        assert {:ok, %{decoded: true} = expected} =
                 Traversal.decode_external_text_part(lower, data)

        assert Traversal.decode_external_text_part(entry, data) ==
                 {:ok, %{expected | charset: charset}}
      end
    end

    test "IANA aliases, utf8 and cp1252 decode like the names they stand for" do
      # Aliases from the IANA character set registry, plus the common utf8 and
      # cp1252. The UTF-8 and US-ASCII inputs are recorded format=full text.
      utf8 = Base.url_encode64(text_part(traverse!(hd(thread_payloads())), "0").content)

      ascii =
        Base.url_encode64(text_part(traverse!(payload("message_full_charsets")), "1").content)

      for {name, aliases, data} <- [
            {"utf-8", ~w(utf8 csUTF8), utf8},
            {"us-ascii",
             ~w(ANSI_X3.4-1968 iso-ir-6 ANSI_X3.4-1986 ISO_646.irv:1991 ISO646-US us IBM367
                cp367 csASCII), ascii},
            {"iso-8859-1",
             ~w(ISO_8859-1:1987 iso-ir-100 ISO_8859-1 latin1 l1 IBM819 CP819 csISOLatin1),
             @latin1},
            {"iso-8859-15", ~w(ISO_8859-15 Latin-9 csISO885915), @latin9},
            {"windows-1252", ~w(cp1252 cswindows1252), @windows_1252}
          ],
          alias_name <- aliases do
        entry = %{part_id: "0", mime_type: "text/plain", charset: name}

        assert {:ok, %{decoded: true} = expected} =
                 Traversal.decode_external_text_part(entry, data)

        assert Traversal.decode_external_text_part(%{entry | charset: alias_name}, data) ==
                 {:ok, %{expected | charset: alias_name}},
               "#{alias_name} should decode like #{name}"
      end
    end

    test "Windows-1252 and ISO-8859-15 map every defined byte as their code pages do" do
      # Expected code points from Python's cp1252 and iso8859_15 codecs.
      undefined = [0x81, 0x8D, 0x8F, 0x90, 0x9D]
      cp1252 = for byte <- 0x80..0xFF, byte not in undefined, into: "", do: <<byte>>
      latin9 = for byte <- 0xA0..0xFF, into: "", do: <<byte>>

      assert {:ok, %{content: cp1252_text}} =
               Traversal.decode_external_text_part(
                 %{part_id: "1", mime_type: "text/plain", charset: "windows-1252"},
                 Base.url_encode64(cp1252)
               )

      assert String.to_charlist(cp1252_text) ==
               [
                 0x20AC,
                 0x201A,
                 0x0192,
                 0x201E,
                 0x2026,
                 0x2020,
                 0x2021,
                 0x02C6,
                 0x2030,
                 0x0160,
                 0x2039,
                 0x0152,
                 0x017D,
                 0x2018,
                 0x2019,
                 0x201C,
                 0x201D,
                 0x2022,
                 0x2013,
                 0x2014,
                 0x02DC,
                 0x2122,
                 0x0161,
                 0x203A,
                 0x0153,
                 0x017E,
                 0x0178
               ] ++ Enum.to_list(0xA0..0xFF)

      assert {:ok, %{content: latin9_text}} =
               Traversal.decode_external_text_part(
                 %{part_id: "1", mime_type: "text/plain", charset: "iso-8859-15"},
                 Base.url_encode64(latin9)
               )

      latin9_changes = %{
        0xA4 => 0x20AC,
        0xA6 => 0x0160,
        0xA8 => 0x0161,
        0xB4 => 0x017D,
        0xB8 => 0x017E,
        0xBC => 0x0152,
        0xBD => 0x0153,
        0xBE => 0x0178
      }

      assert String.to_charlist(latin9_text) ==
               Enum.map(0xA0..0xFF, &Map.get(latin9_changes, &1, &1))
    end

    test "invalid base64url in fetched data returns a provider error" do
      assert {:error,
              %Error.ProviderError{reason: :invalid_base64url, details: %{part_id: "0.0.0"}}} =
               Traversal.decode_external_text_part(
                 %{part_id: "0.0.0", mime_type: "text/plain", charset: "iso-8859-1"},
                 "*" <> @latin1
               )
    end
  end

  describe "attachment manifest" do
    test "lists every attachment with Gmail's identity and no invented attachment ID" do
      assert {:ok, traversal} = Traversal.traverse(payload("message_full_attachments"))

      manifest =
        Enum.map(traversal.attachments, fn entry ->
          Map.update!(entry, :attachment_id, &supplied/1)
        end)

      assert manifest == [
               %{
                 part_id: "0.1",
                 attachment_id: :supplied,
                 filename: "logo.png",
                 mime_type: "image/png",
                 size: 73,
                 disposition: "inline",
                 content_id: "<jcl-logo>"
               },
               %{
                 part_id: "3",
                 attachment_id: :supplied,
                 filename: "notes.txt",
                 mime_type: "text/plain",
                 size: 27,
                 disposition: "attachment",
                 content_id: nil
               },
               %{
                 part_id: "4",
                 attachment_id: :supplied,
                 filename: "data.bin",
                 mime_type: "application/octet-stream",
                 size: 4096,
                 disposition: "attachment",
                 content_id: nil
               },
               %{
                 part_id: "5",
                 attachment_id: nil,
                 filename: "empty.bin",
                 mime_type: "application/octet-stream",
                 size: 0,
                 disposition: "attachment",
                 content_id: nil
               },
               %{
                 part_id: "6",
                 attachment_id: :supplied,
                 filename: "report.csv",
                 mime_type: "text/csv",
                 size: 16,
                 disposition: "attachment",
                 content_id: nil
               },
               %{
                 part_id: "7",
                 attachment_id: :supplied,
                 filename: "report.csv",
                 mime_type: "text/csv",
                 size: 23,
                 disposition: "attachment",
                 content_id: nil
               }
             ]
    end

    test "a named text/plain attachment lands in the manifest, not in the body" do
      assert {:ok, traversal} = Traversal.traverse(payload("message_full_attachments"))

      assert %{filename: "notes.txt", mime_type: "text/plain"} =
               Enum.find(traversal.attachments, &(&1.part_id == "3"))

      refute Enum.any?(traversal.text_parts, &(&1.part_id == "3"))
      refute Enum.any?(traversal.external_text_parts, &(&1.part_id == "3"))
    end

    test "containers and nested messages take precedence over filename and disposition" do
      # Gmail names both enclosed messages and disposes them as attachments.
      forward = traverse!(payload("message_full_forward_attached"))

      assert Enum.map(forward.messages, &{&1.part_id, &1.filename, &1.disposition}) == [
               {"1", "original.eml", "attachment"},
               {"2", "simple.eml", "attachment"}
             ]

      assert forward.attachments == []

      # No recording names a multipart part, so this variant gives the recorded
      # multipart/related part 0 a filename and an attachment disposition.
      payload = payload("message_full_attachments")

      variant =
        map_parts(payload, fn
          %{"partId" => "0"} = part ->
            part
            |> Map.put("filename", "bundle")
            |> put_header("Content-Disposition", ~s(attachment; filename="bundle"))

          part ->
            part
        end)

      assert traverse!(variant) == traverse!(payload)
    end

    test "an attachment disposition in any case and without a filename makes an attachment" do
      # Gmail's recordings name every attachment. This variant disposes the
      # unnamed inline text part 1 as `Attachment`, without a filename.
      variant =
        map_parts(payload("message_full_attachments"), fn
          %{"partId" => "1"} = part -> put_header(part, "Content-Disposition", "Attachment")
          part -> part
        end)

      traversal = traverse!(variant)

      refute Enum.any?(traversal.text_parts, &(&1.part_id == "1"))

      assert Enum.find(traversal.attachments, &(&1.part_id == "1")) == %{
               part_id: "1",
               attachment_id: nil,
               filename: nil,
               mime_type: "text/plain",
               size: 35,
               disposition: "attachment",
               content_id: nil
             }
    end

    test "an inline part keeps its data inline and gets no attachment ID" do
      payload = payload("message_full_attachments")
      empty_bin = Enum.find(payload["parts"], &(&1["partId"] == "5"))

      # Gmail returns empty.bin inline, without an attachmentId.
      assert empty_bin["body"] == %{"data" => "", "size" => 0}

      assert {:ok, traversal} = Traversal.traverse(payload)
      assert %{attachment_id: nil} = Enum.find(traversal.attachments, &(&1.part_id == "5"))
      refute Enum.any?(traversal.text_parts, &Map.has_key?(&1, :attachment_id))
    end
  end

  describe "message/rfc822 parts" do
    test "parts with Gmail-supplied nested parts become nested messages under their part ID" do
      assert {:ok, traversal} = Traversal.traverse(payload("message_full_forward_attached"))

      assert [%{part_id: "0", content: "Two originals attached as messages.\r\n"}] =
               traversal.text_parts

      assert traversal.attachments == []
      assert [original, simple] = traversal.messages

      assert %{
               part_id: "1",
               filename: "original.eml",
               mime_type: "message/rfc822",
               size: 1072,
               disposition: "attachment",
               content_id: nil
             } = original

      assert supplied(original.attachment_id) == :supplied
      assert header(original, "Subject") == "jcl-live attached original"
      assert header(original, "From") == "Person 3 <person-4@example.com>"
      assert header(original, "Date") == "Mon, 26 Oct 2026 15:30:21 +0000"

      assert Enum.map(original.text_parts, &{&1.part_id, &1.mime_type, &1.content}) == [
               {"1.0.0.0", "text/plain",
                "Attached original with marker jcl-marker-forward-attached.\r\n"},
               {"1.0.0.1", "text/html",
                "<p>Attached original with marker <b>jcl-marker-forward-attached</b>.</p>"}
             ]

      assert [%{part_id: "1.0.1", filename: "inner.txt", mime_type: "text/plain"}] =
               original.attachments

      assert original.messages == []
      assert original.external_text_parts == []

      assert %{part_id: "2", filename: "simple.eml"} = simple
      assert header(simple, "Subject") == "jcl-live simple original"

      assert [
               %{
                 part_id: "2.0",
                 content: "A single-part original, marker jcl-marker-forward-simple.\r\n"
               }
             ] =
               simple.text_parts
    end

    test "a part without nested parts is a message/rfc822 manifest entry" do
      # Gmail split even the base64-encoded message/rfc822 part of the charset
      # message into nested parts, so no recording holds an opaque one. This
      # variant drops the nested parts from that recorded part.
      payload = payload("message_full_charsets")
      assert {:ok, %{messages: [%{part_id: "3"}], attachments: []}} = Traversal.traverse(payload)

      opaque_payload =
        Map.update!(payload, "parts", fn parts ->
          Enum.map(parts, fn
            %{"partId" => "3"} = part -> Map.delete(part, "parts")
            part -> part
          end)
        end)

      assert {:ok, traversal} = Traversal.traverse(opaque_payload)
      assert traversal.messages == []

      assert [entry] = traversal.attachments

      assert %{entry | attachment_id: supplied(entry.attachment_id)} == %{
               part_id: "3",
               attachment_id: :supplied,
               filename: "opaque.eml",
               mime_type: "message/rfc822",
               size: 399,
               disposition: "attachment",
               content_id: nil
             }
    end
  end

  describe "base64url" do
    test "decodes Gmail's padded data and the same data without padding" do
      payload = payload("message_full_attachments")
      data = collect_data(payload)

      # Gmail pads body.data. The unpadded variant strips that padding from the
      # recording, since Gmail itself does not send it.
      assert Enum.any?(data, &String.ends_with?(&1, "="))
      assert Enum.all?(data, &(rem(byte_size(&1), 4) == 0))

      unpadded =
        map_parts(payload, &update_data(&1, fn data -> String.trim_trailing(data, "=") end))

      refute Enum.any?(collect_data(unpadded), &String.ends_with?(&1, "="))

      assert {:ok, padded_traversal} = Traversal.traverse(payload)
      assert Traversal.traverse(unpadded) == {:ok, padded_traversal}
    end

    test "invalid base64url returns a provider error without the data" do
      # Gmail sends valid base64url; this variant puts a character outside the
      # alphabet into the recorded data.
      payload = payload("message_full_single_part")
      invalid = update_data(payload, &("*" <> &1))

      assert {:error,
              %Error.ProviderError{
                provider: :google,
                reason: :invalid_base64url,
                details: %{part_id: ""}
              } = error} = Traversal.traverse(invalid)

      refute inspect(error) =~ payload["body"]["data"]
    end
  end

  describe "structural bounds" do
    test "max_depth admits parts at the limit and rejects deeper ones" do
      # The deepest parts of the attachment message are at depth 3 (0.0.0 under
      # 0.0 under 0 under the root payload at depth 0).
      payload = payload("message_full_attachments")

      assert {:ok, _traversal} = Traversal.traverse(payload, max_depth: 3)

      assert {:error,
              %Error.ProviderError{
                reason: :mime_depth_exceeded,
                details: %{max_depth: 2, part_id: "0.0.0"}
              }} = Traversal.traverse(payload, max_depth: 2)
    end

    test "max_depth counts the parts of nested messages" do
      payload = payload("message_full_forward_attached")

      assert {:ok, _traversal} = Traversal.traverse(payload, max_depth: 4)

      assert {:error,
              %Error.ProviderError{
                reason: :mime_depth_exceeded,
                details: %{max_depth: 3, part_id: "1.0.0.0"}
              }} = Traversal.traverse(payload, max_depth: 3)
    end

    test "max_parts counts every part, containers included" do
      # 13 parts: the root, two containers, the related image, the two
      # alternatives and seven parts of the outer mixed container.
      payload = payload("message_full_attachments")

      assert {:ok, _traversal} = Traversal.traverse(payload, max_parts: 13)

      assert {:error,
              %Error.ProviderError{
                reason: :mime_parts_exceeded,
                details: %{max_parts: 12, part_id: "7"}
              }} = Traversal.traverse(payload, max_parts: 12)
    end

    test "max_parts counts the parts of nested messages" do
      # 10 parts: the root, its text part, the first enclosed message with its
      # five parts, and the second enclosed message with its text part 2.0.
      payload = payload("message_full_forward_attached")

      assert {:ok, _traversal} = Traversal.traverse(payload, max_parts: 10)

      assert {:error,
              %Error.ProviderError{
                reason: :mime_parts_exceeded,
                details: %{max_parts: 9, part_id: "2.0"}
              }} = Traversal.traverse(payload, max_parts: 9)
    end

    test "the defaults admit every recording" do
      for name <- [
            "message_full_single_part",
            "message_full_attachments",
            "message_full_forward_attached",
            "message_full_charsets"
          ] do
        assert {:ok, _traversal} = Traversal.traverse(payload(name))
      end
    end

    test "a malformed payload returns a provider error" do
      # Gmail sends parts as a list; this variant replaces the recorded list.
      payload = payload("message_full_attachments")

      assert {:error,
              %Error.ProviderError{reason: :invalid_mime_payload, details: %{part_id: ""}}} =
               Traversal.traverse(%{payload | "parts" => %{"0" => hd(payload["parts"])}})

      assert {:error, %Error.ProviderError{reason: :invalid_mime_payload}} =
               Traversal.traverse("not a payload")
    end

    test "invalid options return a validation error" do
      payload = payload("message_full_single_part")

      for opts <- [
            [max_depth: -1],
            [max_depth: "3"],
            [max_parts: 0],
            [max_bytes: 10],
            [:max_depth]
          ] do
        assert {:error, %Error.ValidationError{reason: :invalid_mime_traversal_option}} =
                 Traversal.traverse(payload, opts)
      end
    end
  end

  defp payload(name), do: LiveSmoke.fixture!(:gmail, name)["payload"]

  defp thread_payloads do
    :gmail
    |> LiveSmoke.fixture!("thread_full_conversation")
    |> Map.fetch!("messages")
    |> Enum.map(& &1["payload"])
  end

  defp traverse!(payload) do
    assert {:ok, traversal} = Traversal.traverse(payload)
    traversal
  end

  defp text_part(traversal, part_id),
    do: Enum.find(traversal.text_parts, &(&1.part_id == part_id))

  defp text(traversal, part_id) do
    %{charset: charset, decoded: decoded, content: content} = text_part(traversal, part_id)
    {charset, decoded, content}
  end

  defp external(text_part), do: Map.take(text_part, [:part_id, :mime_type, :charset])

  defp find_part(%{"partId" => part_id} = part, part_id), do: part

  defp find_part(part, part_id),
    do: Enum.find_value(Map.get(part, "parts", []), &find_part(&1, part_id))

  defp map_parts(part, fun) do
    case fun.(part) do
      %{"parts" => parts} = part -> %{part | "parts" => Enum.map(parts, &map_parts(&1, fun))}
      part -> part
    end
  end

  defp collect_data(part) do
    own = if is_binary(part["body"]["data"]), do: [part["body"]["data"]], else: []
    own ++ Enum.flat_map(Map.get(part, "parts", []), &collect_data/1)
  end

  defp update_data(%{"body" => %{"data" => data} = body} = part, fun),
    do: %{part | "body" => %{body | "data" => fun.(data)}}

  defp update_data(part, _fun), do: part

  # Replaces the header `name`, ignoring case, or appends it.
  defp put_header(part, name, value) do
    headers = Map.get(part, "headers", [])
    same? = &(String.downcase(&1["name"]) == String.downcase(name))

    headers =
      if Enum.any?(headers, same?),
        do: Enum.map(headers, &if(same?.(&1), do: %{&1 | "value" => value}, else: &1)),
        else: headers ++ [%{"name" => name, "value" => value}]

    Map.put(part, "headers", headers)
  end

  defp header(%{headers: headers}, name) do
    Enum.find_value(headers, fn %{name: header_name, value: value} ->
      if header_name == name, do: value
    end)
  end

  # Gmail issues a new attachmentId with every response.
  defp supplied(attachment_id) when is_binary(attachment_id) and attachment_id != "",
    do: :supplied

  defp supplied(nil), do: nil
end
