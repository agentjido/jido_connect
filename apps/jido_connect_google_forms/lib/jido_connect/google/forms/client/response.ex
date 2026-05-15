defmodule Jido.Connect.Google.Forms.Client.Response do
  @moduledoc "Google Forms response handling."

  alias Jido.Connect.Google.Forms.Client.Transport
  alias Jido.Connect.Google.Forms.Normalizer

  def handle_form_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.form(body)
  end

  def handle_form_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Forms form response was invalid", body)
  end

  def handle_form_response(response), do: Transport.handle_error_response(response)

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.batch_update_result(body)
  end

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Forms batch update response was invalid", body)
  end

  def handle_batch_update_response(response), do: Transport.handle_error_response(response)
end
