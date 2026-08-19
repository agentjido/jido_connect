defmodule Jido.Connect.Confluence.Client.Spaces do
  @moduledoc "Confluence Cloud space API boundary."

  alias Jido.Connect.{Error}
  alias Jido.Connect.Confluence.Client.{Normalizer, Request, Transport}
  alias Jido.Connect.Confluence.Input.Spaces, as: SpaceInput

  def get(input, %Request{} = request) do
    with {:ok, %{key: key}} <- SpaceInput.validate_get(input) do
      request
      |> get_response(key)
      |> normalize_space(key, request)
    end
  end

  def resolve(key, %Request{} = request) do
    with {:ok, %{key: key}} <- SpaceInput.validate_get(%{key: key}) do
      request
      |> get_response(key)
      |> normalize_space_ref(key)
    end
  end

  defp get_response(request, key) do
    request
    |> Transport.request()
    |> Req.get(url: Request.url(request, "/api/v2/spaces"), params: %{keys: key, limit: 2})
  end

  defp normalize_space({:ok, %{status: status, body: body}}, key, request)
       when status in 200..299 and is_map(body) do
    context = %{account: Request.account(request), site_url: request.endpoint}

    case Normalizer.space(body, key, context) do
      {:ok, result} -> {:ok, result}
      {:error, :not_found} -> space_not_found(key)
      :error -> Transport.invalid_success_response("Confluence space response was invalid", body)
    end
  end

  defp normalize_space({:ok, %{status: status, body: body}}, _key, _request)
       when status in 200..299,
       do: Transport.invalid_success_response("Confluence space response was invalid", body)

  defp normalize_space(response, _key, _request) do
    Transport.handle_error_response(response, message: "Confluence space request failed")
  end

  defp normalize_space_ref({:ok, %{status: status, body: body}}, key)
       when status in 200..299 and is_map(body) do
    case Normalizer.space_ref(body, key) do
      {:ok, result} -> {:ok, result}
      {:error, :not_found} -> space_not_found(key)
      :error -> Transport.invalid_success_response("Confluence space response was invalid", body)
    end
  end

  defp normalize_space_ref({:ok, %{status: status, body: body}}, _key)
       when status in 200..299,
       do: Transport.invalid_success_response("Confluence space response was invalid", body)

  defp normalize_space_ref(response, _key) do
    Transport.handle_error_response(response, message: "Confluence space request failed")
  end

  defp space_not_found(key) do
    {:error,
     Error.provider("Confluence space key was not found",
       provider: :confluence,
       reason: :space_not_found,
       delivery: :response_received,
       details: %{space_key: key}
     )}
  end
end
