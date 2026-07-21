defmodule Jido.Connect.Google.Slides.Client.Response do
  @moduledoc "Google Slides response handling."

  alias Jido.Connect.Google.Slides.Client.Transport
  alias Jido.Connect.Google.Slides.Normalizer

  def handle_presentation_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.presentation(body)
  end

  def handle_presentation_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Slides presentation response was invalid", body)
  end

  def handle_presentation_response(response), do: Transport.handle_error_response(response)

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.batch_update_result(body)
  end

  def handle_batch_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Slides batch update response was invalid", body)
  end

  def handle_batch_update_response(response), do: Transport.handle_error_response(response)

  def handle_thumbnail_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.thumbnail(body)
  end

  def handle_thumbnail_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Slides thumbnail response was invalid", body)
  end

  def handle_thumbnail_response(response), do: Transport.handle_error_response(response)
end
