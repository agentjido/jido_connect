defmodule Jido.Connect.Google.Docs.Client.Response do
  @moduledoc "Google Docs response handling."

  alias Jido.Connect.Google.Docs.Client.Transport
  alias Jido.Connect.Google.Docs.Normalizer

  def handle_document_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.document(body)
  end

  def handle_document_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Docs document response was invalid", body)
  end

  def handle_document_response(response), do: Transport.handle_error_response(response)
end
