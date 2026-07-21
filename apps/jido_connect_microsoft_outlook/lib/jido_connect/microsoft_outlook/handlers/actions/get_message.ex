defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessage do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOutlook.Normalizer

  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :message_id) do
      nil ->
        {:error, :message_id_required}

      message_id ->
        request = Transport.request(access_token)

        case Transport.request(request, :get, url: "/me/messages/#{message_id}") do
          {:ok, %{status: 200, body: body}} when is_map(body) ->
            case Normalizer.message(body) do
              {:ok, message} -> {:ok, %{message: message}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to get Outlook message"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error, message: "Failed to get Outlook message")
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}
end
