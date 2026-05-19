defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.CreateDraft do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOutlook.Normalizer

  @doc """
  Creates a new draft message in the authenticated user's mailbox.

  POST /me/messages with a JSON body containing subject, body, and recipients.
  The message is created as a draft (isDraft: true) by default.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    body = build_draft_body(input)
    request = Transport.request(access_token)

    case Transport.request(request, :post, url: "/me/messages", json: body) do
      {:ok, %{status: 201, body: response_body}} when is_map(response_body) ->
        normalize_response(response_body, :draft)

      {:ok, %{status: 200, body: response_body}} when is_map(response_body) ->
        normalize_response(response_body, :draft)

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to create Outlook draft"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: "Failed to create Outlook draft")
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_draft_body(input) do
    body = %{}

    body =
      case Map.get(input, :subject) do
        nil -> body
        subject -> Map.put(body, "subject", subject)
      end

    body =
      case Map.get(input, :body) do
        nil ->
          body

        content ->
          content_type =
            case Map.get(input, :content_type, "text") do
              "html" -> "html"
              _ -> "text"
            end

          Map.put(body, "body", %{"contentType" => content_type, "content" => content})
      end

    body =
      case Map.get(input, :to) do
        nil -> body
        recipients -> Map.put(body, "toRecipients", format_recipients(recipients))
      end

    body
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

  defp normalize_response(response_body, key) do
    case Normalizer.message(response_body) do
      {:ok, message} -> {:ok, %{key => message}}
      {:error, _reason} = error -> error
    end
  end
end
