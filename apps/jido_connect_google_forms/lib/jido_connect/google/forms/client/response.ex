defmodule Jido.Connect.Google.Forms.Client.Response do
  @moduledoc "Google Forms response handling."

  alias Jido.Connect.Data
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

  def handle_response_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, responses} <-
           normalize_items(
             body,
             "responses",
             &Normalizer.response/1,
             "Google Forms response list response was invalid"
           ) do
      {:ok,
       %{
         responses: responses,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_response_list_response({:ok, %{status: _status, body: body}})
      when is_map(body) do
    Transport.invalid_success_response("Google Forms response list response was invalid", body)
  end

  def handle_response_list_response(response), do: Transport.handle_error_response(response)

  def handle_response_get_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Normalizer.response(body)
  end

  def handle_response_get_response({:ok, %{status: _status, body: body}})
      when is_map(body) do
    Transport.invalid_success_response("Google Forms response get response was invalid", body)
  end

  def handle_response_get_response(response), do: Transport.handle_error_response(response)

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end
end
