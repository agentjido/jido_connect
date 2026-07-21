defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendMessage do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Sends a new mail message directly (not via draft).

  POST /me/sendMail with a JSON envelope containing the message.
  Returns 202 Accepted with no body on success.
  To retrieve the sent message, we return a confirmation without the full message.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    body = build_send_body(input)
    request = Transport.request(access_token)

    case Transport.request(request, :post, url: "/me/sendMail", json: body) do
      {:ok, %{status: 202}} ->
        {:ok, %{sent: true}}

      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, %{sent: true}}

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to send Outlook message"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: "Failed to send Outlook message")
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_send_body(input) do
    message = %{}

    message =
      case Map.get(input, :subject) do
        nil -> message
        subject -> Map.put(message, "subject", subject)
      end

    message =
      case Map.get(input, :body) do
        nil ->
          message

        content ->
          content_type =
            case Map.get(input, :content_type, "text") do
              "html" -> "html"
              _ -> "text"
            end

          Map.put(message, "body", %{"contentType" => content_type, "content" => content})
      end

    message =
      case Map.get(input, :to) do
        nil -> message
        recipients -> Map.put(message, "toRecipients", format_recipients(recipients))
      end

    message =
      case Map.get(input, :cc) do
        nil -> message
        [] -> message
        recipients -> Map.put(message, "ccRecipients", format_recipients(recipients))
      end

    message =
      case Map.get(input, :bcc) do
        nil -> message
        [] -> message
        recipients -> Map.put(message, "bccRecipients", format_recipients(recipients))
      end

    message =
      case Map.get(input, :reply_to) do
        nil -> message
        [] -> message
        recipients -> Map.put(message, "replyTo", format_recipients(recipients))
      end

    %{"message" => message}
  end

  defp format_recipients(recipients) when is_list(recipients) do
    Enum.map(recipients, &format_recipient/1)
  end

  defp format_recipients(_), do: []

  defp format_recipient(address) when is_binary(address) do
    %{"emailAddress" => %{"address" => address}}
  end

  defp format_recipient(%{"emailAddress" => _} = recipient), do: recipient
  defp format_recipient(%{address: address}), do: %{"emailAddress" => %{"address" => address}}
end
