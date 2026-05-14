defmodule Jido.Connect.Google.Analytics.Client.Response do
  @moduledoc "Google Analytics response handling."

  alias Jido.Connect.Google.Analytics.{Client.Transport, Normalizer}

  def handle_metadata_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.metadata/1, "Google Analytics metadata response was invalid")
  end

  def handle_metadata_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Analytics metadata response was invalid", body)
  end

  def handle_metadata_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end
end
