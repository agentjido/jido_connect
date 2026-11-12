defmodule Jido.Connect.Gmail.MIME do
  @moduledoc """
  Builds and validates Gmail raw MIME payloads for send and draft actions.

  `build_raw/1` serves `google.gmail.message.send`, `google.gmail.draft.create`
  and `google.gmail.draft.update`. It trims recipients, the subject and the
  body, and emits one UTF-8 body part, HTML when both bodies are given. The
  body goes out as `8bit` under `charset=UTF-8`.

  A subject with a character outside ASCII goes out as RFC 2047 encoded
  words, `=?UTF-8?B?...?=`, each holding at most 39 bytes of whole UTF-8
  code points, folded so that no line of the `Subject` header exceeds 76
  characters. An ASCII subject goes out unchanged, on one line. When the
  live test created a draft with a raw UTF-8 subject, Gmail stored the
  subject garbled and the `8bit` body with its bytes; sending was not tried
  with a raw subject.

  A header value in the input must not break the line. After trimming, a CR
  or LF in `subject`, `in_reply_to` or `references` fails with reason
  `:invalid_header_value` and the field in the details, because the break
  would start a header of its own, such as `Bcc:`. `in_reply_to` and
  `references` are not trimmed, so a trailing break fails as well. They must
  be `nil` or a string; `nil` and `""` leave the header out, and any other
  value, such as a list, fails with the same reason. A recipient must match
  a plain address pattern without whitespace, so a break inside one fails
  with `:invalid_recipient`. In both cases nothing is encoded and the action
  makes no provider call. The header error does not repeat the value, which
  is message content.
  """

  alias Jido.Connect.{Data, Error}

  @email_pattern ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

  @doc "Validates a message input and returns Gmail base64url-encoded raw MIME."
  def build_raw(input) when is_map(input) do
    with {:ok, to} <- validate_required_recipients(:to, Data.get(input, :to)),
         {:ok, cc} <- validate_optional_recipients(:cc, Data.get(input, :cc, [])),
         {:ok, bcc} <- validate_optional_recipients(:bcc, Data.get(input, :bcc, [])),
         {:ok, subject} <- require_text(:subject, Data.get(input, :subject)),
         :ok <-
           single_line(
             subject: subject,
             in_reply_to: Data.get(input, :in_reply_to),
             references: Data.get(input, :references)
           ),
         {:ok, body, content_type} <- body(input) do
      {:ok,
       input
       |> headers(to, cc, bcc, subject, content_type)
       |> Kernel.++(["", body])
       |> Enum.join("\r\n")
       |> Base.url_encode64(padding: false)}
    end
  end

  defp headers(input, to, cc, bcc, subject, content_type) do
    []
    |> put_header("To", Enum.join(to, ", "))
    |> put_header("Cc", Enum.join(cc, ", "))
    |> put_header("Bcc", Enum.join(bcc, ", "))
    |> put_header("Subject", encode_subject(subject))
    |> put_header("In-Reply-To", Data.get(input, :in_reply_to))
    |> put_header("References", Data.get(input, :references))
    |> put_header("MIME-Version", "1.0")
    |> put_header("Content-Type", content_type <> "; charset=UTF-8")
    |> put_header("Content-Transfer-Encoding", "8bit")
  end

  # RFC 2047, section 2, limits an encoded word to 75 characters and each
  # line of a header field that holds one to 76. 39 bytes of UTF-8 make a
  # word of at most 64 characters, a first line of at most 73 after
  # "Subject: " and continuation lines of at most 65.
  @encoded_word_bytes 39

  defp encode_subject(subject) do
    if ascii?(subject) do
      subject
    else
      subject
      |> chunk_characters(@encoded_word_bytes)
      |> Enum.map_join("\r\n ", &("=?UTF-8?B?" <> Base.encode64(&1) <> "?="))
    end
  end

  defp ascii?(<<byte, rest::binary>>) when byte < 0x80, do: ascii?(rest)
  defp ascii?(<<>>), do: true
  defp ascii?(_value), do: false

  # Every chunk holds whole code points, so each encoded word decodes on its
  # own, as RFC 2047 requires.
  defp chunk_characters(text, max_bytes) do
    text
    |> String.codepoints()
    |> Enum.chunk_while(
      "",
      fn char, chunk ->
        if byte_size(chunk) + byte_size(char) <= max_bytes,
          do: {:cont, chunk <> char},
          else: {:cont, chunk, char}
      end,
      &{:cont, &1, ""}
    )
  end

  defp put_header(headers, _name, value) when value in [nil, ""], do: headers

  defp put_header(headers, name, value) when is_binary(value),
    do: headers ++ ["#{name}: #{value}"]

  defp body(input) do
    cond do
      present?(Data.get(input, :body_html)) ->
        {:ok, String.trim(Data.get(input, :body_html)), "text/html"}

      present?(Data.get(input, :body_text)) ->
        {:ok, String.trim(Data.get(input, :body_text)), "text/plain"}

      true ->
        validation_error("Gmail message requires body_text or body_html",
          field: :body,
          reason: :missing_body
        )
    end
  end

  defp validate_required_recipients(field, recipients) do
    with {:ok, recipients} <- validate_optional_recipients(field, recipients) do
      if recipients == [] do
        validation_error("Gmail message requires at least one #{field} recipient",
          field: field,
          reason: :missing_recipient
        )
      else
        {:ok, recipients}
      end
    end
  end

  defp validate_optional_recipients(field, nil), do: validate_optional_recipients(field, [])

  defp validate_optional_recipients(field, recipient) when is_binary(recipient),
    do: validate_optional_recipients(field, [recipient])

  defp validate_optional_recipients(field, recipients) when is_list(recipients) do
    recipients =
      Enum.map(recipients, fn
        recipient when is_binary(recipient) -> String.trim(recipient)
        other -> other
      end)

    case Enum.find(recipients, &(not valid_email?(&1))) do
      nil ->
        {:ok, Enum.reject(recipients, &(&1 == ""))}

      invalid ->
        validation_error("Invalid Gmail #{field} recipient",
          field: field,
          reason: :invalid_recipient,
          recipient: invalid
        )
    end
  end

  defp validate_optional_recipients(field, _recipients) do
    validation_error("Gmail #{field} recipients must be a list of email addresses",
      field: field,
      reason: :invalid_recipient
    )
  end

  defp valid_email?(recipient) when is_binary(recipient),
    do: Regex.match?(@email_pattern, recipient)

  defp valid_email?(_recipient), do: false

  defp require_text(field, value) when is_binary(value) do
    if present?(value) do
      {:ok, String.trim(value)}
    else
      validation_error("Gmail #{field} must not be blank", field: field, reason: :blank_field)
    end
  end

  defp require_text(field, _value),
    do: validation_error("Gmail #{field} is required", field: field, reason: :missing_field)

  # The subject has passed require_text/2 here, so only the threading headers
  # can be nil or something other than a string.
  defp single_line(values) do
    case Enum.find(values, fn {_field, value} -> not single_line?(value) end) do
      nil ->
        :ok

      {field, value} when is_binary(value) ->
        invalid_header(field, "must not contain a line break")

      {field, _value} ->
        invalid_header(field, "must be a string")
    end
  end

  defp single_line?(nil), do: true
  defp single_line?(value) when is_binary(value), do: not String.contains?(value, ["\r", "\n"])
  defp single_line?(_value), do: false

  defp invalid_header(field, problem) do
    validation_error("Gmail #{field} #{problem}", field: field, reason: :invalid_header_value)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp validation_error(message, details) do
    {:error,
     Error.validation(message,
       reason: Keyword.fetch!(details, :reason),
       details: Map.new(details)
     )}
  end
end
