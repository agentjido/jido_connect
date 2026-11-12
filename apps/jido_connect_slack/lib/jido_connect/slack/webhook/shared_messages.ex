defmodule Jido.Connect.Slack.Webhook.SharedMessages do
  @moduledoc false

  # A message a person shares natively into a DM arrives as a `message` event
  # whose `attachments` hold an entry with `is_share: true`. Each such entry
  # becomes a map with the keys a message signal uses for the same facts: the
  # source `channel`, the shared message's `ts`, its author as `user`, its
  # `text`, and Slack's `from_url`. The person who shared it stays the
  # event's `user`.
  #
  # A share without a source channel or ts, or with a field of another type
  # than a string, fails with `:invalid_shared_message`; the details name the
  # payload path and never a value.

  alias Jido.Connect.{Data, Error}

  @doc false
  def from_event(event) do
    case Data.get(event, "attachments") do
      nil ->
        {:ok, nil}

      attachments when is_list(attachments) ->
        attachments
        |> Enum.with_index()
        |> Enum.filter(fn {attachment, _index} -> share?(attachment) end)
        |> shared_messages()

      _other ->
        {:error, invalid("attachments")}
    end
  end

  defp share?(attachment), do: is_map(attachment) and Data.get(attachment, "is_share") == true

  defp shared_messages([]), do: {:ok, nil}

  defp shared_messages(shares) do
    result =
      Enum.reduce_while(shares, {:ok, []}, fn {attachment, index}, {:ok, messages} ->
        case shared_message(attachment, "attachments.#{index}") do
          {:ok, message} -> {:cont, {:ok, [message | messages]}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    with {:ok, messages} <- result, do: {:ok, Enum.reverse(messages)}
  end

  defp shared_message(attachment, path) do
    with {:ok, channel} <- required_string(attachment, "channel_id", path),
         {:ok, ts} <- required_string(attachment, "ts", path),
         {:ok, user} <- optional_string(attachment, "author_id", path),
         {:ok, text} <- optional_string(attachment, "text", path),
         {:ok, from_url} <- optional_string(attachment, "from_url", path) do
      {:ok, Data.compact(%{channel: channel, ts: ts, user: user, text: text, from_url: from_url})}
    end
  end

  defp required_string(attachment, key, path) do
    case Data.get(attachment, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _missing -> {:error, invalid("#{path}.#{key}")}
    end
  end

  defp optional_string(attachment, key, path) do
    case Data.get(attachment, key) do
      value when is_binary(value) or is_nil(value) -> {:ok, value}
      _other -> {:error, invalid("#{path}.#{key}")}
    end
  end

  defp invalid(field) do
    Error.provider("Slack shared message is malformed",
      provider: :slack,
      reason: :invalid_shared_message,
      details: %{field: field}
    )
  end
end
