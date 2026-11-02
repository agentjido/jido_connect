defmodule Jido.Connect.Gmail.MIME.Traversal do
  @default_max_depth 32
  @default_max_parts 500

  @moduledoc """
  Walks the MIME tree of a Gmail `format=full` message payload.

  `traverse/2` takes the `payload` map of a Gmail message and returns four
  lists, each in Gmail's part order:

    * `text_parts`: body `text/plain` and `text/html` parts with their text.
    * `attachments`: the attachment manifest.
    * `external_text_parts`: body text parts whose bytes Gmail stores behind
      an `attachmentId`.
    * `messages`: enclosed `message/rfc822` messages, each with its headers
      and the same four lists.

  The traversal sends no requests. A caller fetches an external text part with
  Gmail's `attachments.get` and passes the returned `data` to
  `decode_external_text_part/2`.

  ## Parts

  Gmail's `partId` is the only part identity. A `multipart/*` part is a
  container, and a `message/rfc822` part with nested parts from Gmail is a
  nested message, whatever their `filename` and disposition. Any other part
  with a non-empty `filename` or the disposition `attachment`, in upper or
  lower case, is an attachment whatever its MIME type, so a named `text/plain`
  part lands in the manifest. The remaining `text/plain` and `text/html` parts
  are body text, and every other part is an attachment.

  The `headers` of a nested message are those of its first nested part, the
  root of the enclosed message, as `%{name: name, value: value}` maps. A
  `message/rfc822` part without nested parts is a manifest entry.

  Manifest entries carry `part_id`, `attachment_id`, `filename`, `mime_type`,
  `size` (Gmail's `body.size`), `disposition` and `content_id` (the
  `Content-ID` header value). `attachment_id` is Gmail's `body.attachmentId`,
  or `nil` when Gmail supplies none; the data then sits in `body.data`, also
  when that is empty. The traversal never invents an attachment ID, and Gmail
  issues a new one with every response. A nested message carries the manifest
  fields of its `message/rfc822` part, `headers` and the four lists.
  An external text part carries `part_id`, `attachment_id`, `mime_type`,
  `charset` and `size`.

  ## Text and charsets

  Text parts use the keys of Google Drive file content (`mime_type`, `size`,
  `content`, `content_base64`, `encoding`) plus `part_id`, `charset` and
  `decoded`. `charset` is the declared charset in lower case, or `us-ascii`
  when the part declares none (RFC 2045). Decoded text sits in `content` with
  `encoding: "utf-8"` and `decoded: true`. Otherwise `content_base64` holds the
  bytes as standard base64, with `encoding: "base64"` and `decoded: false`.
  `size` counts the bytes Gmail returned.

  For `format=full`, Gmail returns the data of every text part already
  converted to UTF-8, whatever charset the part declares; `body.size` still
  counts the original bytes. The traversal therefore reads inline data as
  UTF-8 and returns `decoded: false` only for data that is not valid UTF-8.
  `attachments.get` returns the original bytes, so
  `decode_external_text_part/2` decodes them with the declared charset:
  `utf-8`, `us-ascii`, `iso-8859-1`, `iso-8859-15` or `windows-1252`, also
  under the aliases that `Jido.Connect.Gmail.MIME.Charset` lists. Other
  charsets, and bytes invalid for their charset, stay undecoded. An inline
  `koi8-r` part thus arrives with `decoded: true`, while a `koi8-r` part
  behind an `attachmentId` stays `decoded: false`.

  Gmail pads base64url data; the traversal decodes it with and without
  padding.

  ## Attachment lookup

  `attachment/3` walks the payload like `traverse/2`, under the same bounds,
  and selects the part with a given `partId`: a manifest entry or a nested
  message, whose manifest fields it returns. The root of a message counts
  like any other part, so the `application/pdf` root of a single-part
  message is selected with its part ID `""`. An unknown part ID returns a
  `Jido.Connect.Error.ValidationError` with reason `:unknown_part_id`, and a
  body text part or a container reason `:not_an_attachment`.

  Non-empty `body.data` comes back as `{:inline, data}`. A part with an
  `attachmentId` and empty or no `body.data` comes back as
  `{:external, attachment_id}`, since Gmail's API reference allows empty data
  next to an `attachmentId`. Empty data without an `attachmentId`, as Gmail
  returns an empty file, comes back as `{:inline, ""}`. A part with neither
  data nor an `attachmentId` returns a provider error with reason
  `:attachment_data_missing`.

  Inline data must be valid base64url and decode to `size` bytes, or the
  lookup returns reason `:invalid_base64url` or `:attachment_size_mismatch`.

  Gmail keeps a `text/*` part without a filename inline, also when the
  traversal lists it as an attachment, such as a `text/csv` part or a text
  part with the disposition `attachment`. It returns the data converted to
  UTF-8 like that of body text, while `size` keeps the original count. Such
  a part has no `attachmentId`, so `attachments.get` cannot fetch it; Gmail
  returns its original bytes only within the whole message in `format=raw`,
  which the lookup does not read. Inline `text/*` data therefore counts as
  the original only where the conversion cannot have changed it:

    * Empty data, which has nothing to convert.
    * Data of `size` bytes in a part that declares `utf-8`. Gmail keeps valid
      UTF-8 and turns each invalid byte into a character of two or three
      bytes.
    * 7-bit ASCII data of `size` bytes in a part that declares no charset,
      `us-ascii`, `iso-8859-1` to `iso-8859-10`, `iso-8859-13` to
      `iso-8859-16`, `windows-1250` to `windows-1258`, `koi8-r` or `koi8-u`.
      These charsets decode no byte from 0x80 as ASCII, so a converted byte
      would have left longer or non-ASCII text.

  Charset names match without regard to case, and the aliases that
  `Jido.Connect.Gmail.MIME.Charset` lists count. All other inline `text/*`
  data returns reason `:attachment_converted`: non-ASCII text in a charset
  other than UTF-8, and any text in another charset, such as UTF-16, whose
  UTF-8 form can keep the original length with other bytes.

  `verify_attachment_data/2` applies the base64url and size checks to the
  `data` that `attachments.get` returns for an entry, which holds the
  original bytes.

  ## Bounds

    * `:max_depth`: the deepest part allowed. The root payload is at depth 0,
      each nested part one deeper, the parts of an enclosed message included.
      Default #{@default_max_depth}.
    * `:max_parts`: the number of parts allowed, containers and enclosed
      messages included. Default #{@default_max_parts}.

  A payload beyond a bound returns a `Jido.Connect.Error.ProviderError` with
  reason `:mime_depth_exceeded` or `:mime_parts_exceeded`. Invalid base64url
  returns reason `:invalid_base64url`, a payload of the wrong shape
  `:invalid_mime_payload`, and an invalid option a
  `Jido.Connect.Error.ValidationError`. Errors name the part ID, never its data.
  There is no byte cap; intake limits belong to the host.
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.MIME.Charset
  alias Jido.Connect.Gmail.Normalizer

  @text_types ["text/plain", "text/html"]

  # ASCII-compatible single-byte charsets by their IANA names; see
  # unconverted?/2.
  @single_byte_charsets ~w(us-ascii iso-8859-1 iso-8859-2 iso-8859-3 iso-8859-4 iso-8859-5
                           iso-8859-6 iso-8859-7 iso-8859-8 iso-8859-9 iso-8859-10
                           iso-8859-13 iso-8859-14 iso-8859-15 iso-8859-16 windows-1250
                           windows-1251 windows-1252 windows-1253 windows-1254 windows-1255
                           windows-1256 windows-1257 windows-1258 koi8-r koi8-u)

  @type text_part :: %{
          part_id: String.t(),
          mime_type: String.t(),
          charset: String.t(),
          size: non_neg_integer(),
          content: String.t() | nil,
          content_base64: String.t() | nil,
          encoding: String.t(),
          decoded: boolean()
        }

  @type manifest_entry :: %{
          part_id: String.t(),
          attachment_id: String.t() | nil,
          filename: String.t() | nil,
          mime_type: String.t(),
          size: non_neg_integer() | nil,
          disposition: String.t() | nil,
          content_id: String.t() | nil
        }

  @type external_text_part :: %{
          part_id: String.t(),
          attachment_id: String.t(),
          mime_type: String.t(),
          charset: String.t(),
          size: non_neg_integer() | nil
        }

  @type t :: %{
          text_parts: [text_part()],
          attachments: [manifest_entry()],
          external_text_parts: [external_text_part()],
          messages: [map()]
        }

  @doc "Traverses the `payload` map of a Gmail `format=full` message."
  @spec traverse(term(), keyword()) :: {:ok, t()} | {:error, Error.error()}
  def traverse(payload, opts \\ []) when is_list(opts) do
    with {:ok, limits} <- limits(opts),
         {:ok, content, _state} <- walk(payload, 0, limits, {empty(), new_state()}) do
      {:ok, finish(content)}
    end
  end

  @doc """
  Selects the attachment with Gmail `partId` `part_id` from the `payload` map
  of a Gmail `format=full` message.

  Returns the manifest entry of the part, a nested message included, with
  `{:inline, data}` for data that Gmail returned in `body.data` or
  `{:external, attachment_id}` for data behind an `attachmentId`. The
  attachment lookup section of the moduledoc describes the checks.
  """
  @spec attachment(term(), String.t(), keyword()) ::
          {:ok, manifest_entry(), {:inline, String.t()} | {:external, String.t()}}
          | {:error, Error.error()}
  def attachment(payload, part_id, opts \\ []) when is_binary(part_id) and is_list(opts) do
    with {:ok, limits} <- limits(opts),
         {:ok, _content, state} <-
           walk(payload, 0, Map.put(limits, :select, part_id), {empty(), new_state()}) do
      selected_attachment(state.selected, part_id)
    end
  end

  @doc """
  Checks the `data` that Gmail's `attachments.get` returned for a manifest
  entry: base64url, with or without padding, that decodes to `size` bytes.
  """
  @spec verify_attachment_data(manifest_entry(), String.t()) :: :ok | {:error, Error.error()}
  def verify_attachment_data(%{part_id: part_id} = entry, data) when is_binary(data) do
    with {:ok, bytes} <- decode_base64url(data, part_id), do: check_size(bytes, entry)
  end

  @doc """
  Builds the text part of an entry of `external_text_parts` from the `data`
  that Gmail's `attachments.get` returned for it.
  """
  @spec decode_external_text_part(map(), String.t()) ::
          {:ok, text_part()} | {:error, Error.error()}
  def decode_external_text_part(
        %{part_id: part_id, mime_type: mime_type, charset: charset},
        data
      )
      when is_binary(data) do
    with {:ok, bytes} <- decode_base64url(data, part_id) do
      {:ok,
       Map.merge(
         %{part_id: part_id, mime_type: mime_type, charset: charset},
         text_content(bytes, Charset.decode(bytes, charset))
       )}
    end
  end

  # `state.seen` counts the parts visited so far, across the whole payload;
  # `state.selected` holds the part that attachment/3 looks for, with its kind.
  defp walk(part, depth, limits, {content, state}) when is_map(part) do
    state = %{state | seen: state.seen + 1}

    cond do
      depth > limits.max_depth ->
        bound_error(:mime_depth_exceeded, :max_depth, limits.max_depth, part)

      state.seen > limits.max_parts ->
        bound_error(:mime_parts_exceeded, :max_parts, limits.max_parts, part)

      true ->
        kind = kind(part)
        visit(kind, part, depth, limits, {content, select(state, kind, part, limits)})
    end
  end

  defp walk(_part, _depth, _limits, _acc), do: malformed_error(%{})

  defp visit(:container, part, depth, limits, acc), do: walk_children(part, depth, limits, acc)

  defp visit(:message, part, depth, limits, {content, state}) do
    with {:ok, nested, state} <- walk_children(part, depth, limits, {empty(), state}) do
      [root | _rest] = Data.get(part, "parts")

      message =
        part
        |> manifest_entry()
        |> Map.put(:headers, headers(root))
        |> Map.merge(finish(nested))

      {:ok, prepend(content, :messages, message), state}
    end
  end

  defp visit(:text, part, _depth, _limits, {content, state}) do
    case attachment_id(part) do
      nil ->
        with {:ok, bytes} <- inline_bytes(part) do
          {:ok, prepend(content, :text_parts, text_part(part, bytes)), state}
        end

      attachment_id ->
        entry = external_text_part(part, attachment_id)
        {:ok, prepend(content, :external_text_parts, entry), state}
    end
  end

  defp visit(:attachment, part, _depth, _limits, {content, state}),
    do: {:ok, prepend(content, :attachments, manifest_entry(part)), state}

  defp walk_children(part, depth, limits, acc) do
    case Data.get(part, "parts", []) do
      parts when is_list(parts) ->
        parts
        |> Enum.reduce_while({:ok, acc}, fn child, {:ok, acc} ->
          case walk(child, depth + 1, limits, acc) do
            {:ok, content, state} -> {:cont, {:ok, {content, state}}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, {content, state}} -> {:ok, content, state}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        malformed_error(part)
    end
  end

  defp kind(part) do
    mime_type = mime_type(part)

    cond do
      String.starts_with?(mime_type, "multipart/") -> :container
      mime_type == "message/rfc822" and Data.get(part, "parts", []) not in [[], nil] -> :message
      filename(part) != nil or disposition(part) == "attachment" -> :attachment
      mime_type in @text_types -> :text
      true -> :attachment
    end
  end

  defp select(%{selected: nil} = state, kind, part, %{select: part_id}) do
    if Data.get(part, "partId") == part_id, do: %{state | selected: {kind, part}}, else: state
  end

  defp select(state, _kind, _part, _limits), do: state

  defp selected_attachment({kind, part}, _part_id) when kind in [:attachment, :message],
    do: locate(part)

  defp selected_attachment({_kind, _part}, part_id),
    do: lookup_error(:not_an_attachment, "Gmail message part is not an attachment", part_id)

  defp selected_attachment(nil, part_id),
    do: lookup_error(:unknown_part_id, "Gmail message has no part with this part ID", part_id)

  # Non-empty data comes first. Gmail's API reference allows empty data next
  # to an attachmentId, so empty data is inline only without one, as for an
  # empty file.
  defp locate(part) do
    entry = manifest_entry(part)

    case part |> Data.get("body", %{}) |> Data.get("data") do
      data when data in [nil, ""] and is_binary(entry.attachment_id) ->
        {:ok, entry, {:external, entry.attachment_id}}

      data when is_binary(data) ->
        with :ok <- check_inline(part, entry, data), do: {:ok, entry, {:inline, data}}

      nil ->
        provider_error(
          :attachment_data_missing,
          "Gmail attachment part has neither data nor an attachment ID",
          entry.part_id
        )

      _invalid ->
        malformed_error(part)
    end
  end

  # Gmail converts the format=full data of a text/* part to UTF-8 and keeps
  # body.size at the original count. Empty data has nothing to convert; other
  # text counts as the original only when unconverted?/2 holds.
  defp check_inline(part, entry, data) do
    with {:ok, bytes} <- decode_base64url(data, entry.part_id) do
      cond do
        not String.starts_with?(mime_type(part), "text/") or bytes == "" ->
          check_size(bytes, entry)

        byte_size(bytes) == entry.size and unconverted?(bytes, charset(part)) ->
          :ok

        true ->
          provider_error(
            :attachment_converted,
            "Gmail returned the inline text attachment converted to UTF-8",
            entry.part_id
          )
      end
    end
  end

  # Whether `bytes` of the original length are the original, that is, whether
  # Gmail's conversion to UTF-8 cannot have changed them. It holds for
  #
  #   * UTF-8: Gmail keeps valid UTF-8 and turns each invalid byte into its
  #     Windows-1252 character of two or three bytes; part 2 of
  #     message_full_charsets grew from 76 to 81 bytes that way.
  #   * 7-bit data in an ASCII-compatible single-byte charset. These charsets
  #     decode bytes below 0x80 as ASCII and no other byte as ASCII. A byte
  #     from 0x80 leaves a non-ASCII character in the data, or nothing, which
  #     shortens the data unless a non-ASCII character makes it longer.
  #
  # The second case assumes that Gmail never decodes a byte from 0x80 into an
  # ASCII character such as "?". Other charsets stay out. UTF-16 and UTF-32
  # text can keep its length in UTF-8, as part 6 of
  # message_full_unnamed_attachments did, and multi-byte and escape-based
  # charsets can turn several bytes into a character just as long.
  defp unconverted?(bytes, charset) do
    case Charset.canonical(charset) do
      "utf-8" -> true
      charset -> charset in @single_byte_charsets and ascii?(bytes)
    end
  end

  defp ascii?(bytes), do: match?({:ok, _text}, Charset.decode(bytes, "us-ascii"))

  defp check_size(bytes, %{part_id: part_id, size: size}) do
    if byte_size(bytes) == size do
      :ok
    else
      provider_error(
        :attachment_size_mismatch,
        "Gmail attachment data does not match the part size",
        part_id
      )
    end
  end

  defp mime_type(part) do
    case Data.get(part, "mimeType") do
      mime_type when is_binary(mime_type) -> String.downcase(mime_type)
      _none -> ""
    end
  end

  # Gmail has already converted format=full data to UTF-8, whatever charset
  # the part declares.
  defp text_part(part, bytes) do
    Map.merge(
      %{
        part_id: Data.get(part, "partId"),
        mime_type: Data.get(part, "mimeType"),
        charset: charset(part)
      },
      text_content(bytes, Charset.decode(bytes, "utf-8"))
    )
  end

  defp text_content(bytes, {:ok, text}) do
    %{
      size: byte_size(bytes),
      content: text,
      content_base64: nil,
      encoding: "utf-8",
      decoded: true
    }
  end

  defp text_content(bytes, :error) do
    %{
      size: byte_size(bytes),
      content: nil,
      content_base64: Base.encode64(bytes),
      encoding: "base64",
      decoded: false
    }
  end

  defp external_text_part(part, attachment_id) do
    %{
      part_id: Data.get(part, "partId"),
      attachment_id: attachment_id,
      mime_type: Data.get(part, "mimeType"),
      charset: charset(part),
      size: body_size(part)
    }
  end

  defp manifest_entry(part) do
    %{
      part_id: Data.get(part, "partId"),
      attachment_id: attachment_id(part),
      filename: filename(part),
      mime_type: Data.get(part, "mimeType"),
      size: body_size(part),
      disposition: disposition(part),
      content_id: header(part, "content-id")
    }
  end

  defp body_size(part), do: part |> Data.get("body", %{}) |> Data.get("size")

  defp attachment_id(part) do
    case part |> Data.get("body", %{}) |> Data.get("attachmentId") do
      attachment_id when is_binary(attachment_id) and attachment_id != "" -> attachment_id
      _none -> nil
    end
  end

  defp filename(part) do
    case Data.get(part, "filename") do
      filename when is_binary(filename) and filename != "" -> filename
      _none -> nil
    end
  end

  # RFC 2045: a text part without a charset parameter is US-ASCII.
  defp charset(part) do
    with value when is_binary(value) <- header(part, "content-type"),
         [_match, charset] <- Regex.run(~r/;\s*charset\s*=\s*"?([^";\s]+)"?/i, value) do
      String.downcase(charset)
    else
      _none -> "us-ascii"
    end
  end

  defp disposition(part) do
    case header(part, "content-disposition") do
      nil -> nil
      value -> value |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()
    end
  end

  defp headers(part), do: Normalizer.normalize_headers(Data.get(part, "headers", []))

  defp header(part, name) do
    part
    |> headers()
    |> Enum.find_value(fn header -> if String.downcase(header.name) == name, do: header.value end)
  end

  defp inline_bytes(part) do
    case part |> Data.get("body", %{}) |> Data.get("data", "") do
      data when is_binary(data) -> decode_base64url(data, Data.get(part, "partId"))
      _invalid -> malformed_error(part)
    end
  end

  defp decode_base64url(data, part_id) do
    case Base.url_decode64(data, padding: false) do
      {:ok, bytes} ->
        {:ok, bytes}

      :error ->
        {:error,
         Error.provider("Gmail MIME part data is not valid base64url",
           provider: :google,
           reason: :invalid_base64url,
           details: %{part_id: part_id}
         )}
    end
  end

  defp limits(opts) do
    defaults = %{max_depth: @default_max_depth, max_parts: @default_max_parts}

    Enum.reduce_while(opts, {:ok, defaults}, fn
      {:max_depth, value}, {:ok, limits} when is_integer(value) and value >= 0 ->
        {:cont, {:ok, %{limits | max_depth: value}}}

      {:max_parts, value}, {:ok, limits} when is_integer(value) and value > 0 ->
        {:cont, {:ok, %{limits | max_parts: value}}}

      option, _acc ->
        {:halt, option_error(option)}
    end)
  end

  defp option_error(option) do
    name = if is_tuple(option), do: elem(option, 0), else: option

    {:error,
     Error.validation(
       "Gmail MIME traversal accepts integer max_depth >= 0 and max_parts >= 1",
       reason: :invalid_mime_traversal_option,
       details: %{option: name}
     )}
  end

  defp bound_error(reason, option, limit, part) do
    {:error,
     Error.provider("Gmail message exceeds the MIME traversal #{option}",
       provider: :google,
       reason: reason,
       details: %{option => limit, part_id: Data.get(part, "partId")}
     )}
  end

  defp malformed_error(part) do
    {:error,
     Error.provider("Gmail MIME payload is malformed",
       provider: :google,
       reason: :invalid_mime_payload,
       details: %{part_id: Data.get(part, "partId")}
     )}
  end

  defp lookup_error(reason, message, part_id),
    do: {:error, Error.validation(message, reason: reason, details: %{part_id: part_id})}

  defp provider_error(reason, message, part_id),
    do:
      {:error,
       Error.provider(message, provider: :google, reason: reason, details: %{part_id: part_id})}

  defp empty, do: %{text_parts: [], attachments: [], external_text_parts: [], messages: []}

  defp new_state, do: %{seen: 0, selected: nil}

  defp prepend(content, key, item), do: Map.update!(content, key, &[item | &1])

  defp finish(content), do: Map.new(content, fn {key, items} -> {key, Enum.reverse(items)} end)
end
