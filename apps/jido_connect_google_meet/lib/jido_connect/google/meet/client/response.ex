defmodule Jido.Connect.Google.Meet.Client.Response do
  @moduledoc "Google Meet response handling."

  alias Jido.Connect.Google.Meet.{Client.Transport, Normalizer}

  def handle_space_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.space/1, "Google Meet space response was invalid")
  end

  def handle_space_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet space response was invalid", body)
  end

  def handle_space_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end
end
