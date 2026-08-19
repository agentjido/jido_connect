defmodule Jido.Connect.MicrosoftSharepoint.Client.Response do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.Normalizer

  @spec single(term(), (map() -> {:ok, struct()} | {:error, term()}), atom(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def single(result, normalizer, output_key, message) do
    case result do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case normalizer.(body) do
          {:ok, resource} -> {:ok, %{output_key => resource}}
          {:error, _reason} -> Transport.invalid_success_response(message, body)
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response}, message: message)

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: message)
    end
  end

  @spec page(term(), (map() -> {:ok, struct()} | {:error, term()}), atom(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def page(result, normalizer, output_key, message) do
    case result do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case Normalizer.page(body, normalizer) do
          {:ok, %{items: items, next_link: next_link}} ->
            {:ok, %{output_key => items, next_link: next_link}}

          {:error, _reason} ->
            Transport.invalid_success_response(message, body)
        end

      {:ok, response} ->
        Transport.handle_error_response({:ok, response}, message: message)

      {:error, _reason} = error ->
        Transport.handle_error_response(error, message: message)
    end
  end
end
