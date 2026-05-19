defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendDraft do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Sends an existing draft message.

  POST /me/messages/{draft_id}/send returns 202 Accepted with no body on success.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :draft_id) do
      nil ->
        {:error, :draft_id_required}

      draft_id ->
        request = Transport.request(access_token)

        case Transport.request(request, :post, url: "/me/messages/#{draft_id}/send") do
          {:ok, %{status: 202}} ->
            {:ok, %{sent: true, draft_id: draft_id}}

          {:ok, %{status: status}} when is_integer(status) and status in 200..299 ->
            {:ok, %{sent: true, draft_id: draft_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to send Outlook draft"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error, message: "Failed to send Outlook draft")
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
