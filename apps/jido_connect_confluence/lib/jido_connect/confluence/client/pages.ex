defmodule Jido.Connect.Confluence.Client.Pages do
  @moduledoc "Confluence Cloud page read and lifecycle API boundary."

  alias Jido.Connect.Error
  alias Jido.Connect.Confluence.{ADF, Input.Pages, Client.Spaces}
  alias Jido.Connect.Confluence.Client.{Normalizer, Request, Transport}

  def list(input, %Request{} = request) do
    with {:ok, input} <- Pages.validate_list(input),
         {:ok, space} <- Spaces.resolve(input.space_key, request) do
      params = maybe_put(%{limit: input.limit}, :cursor, input.cursor)

      request
      |> Transport.request()
      |> Req.get(
        url: Request.url(request, "/api/v2/spaces/#{path_segment(space.id)}/pages"),
        params: params
      )
      |> normalize_list(space, request, input.limit)
    end
  end

  def get(input, %Request{} = request) do
    with {:ok, input} <- Pages.validate_get(input) do
      request
      |> fetch_raw(input.id)
      |> normalize_page(input.id, input.max_characters, request)
    end
  end

  def create(input, %Request{} = request) do
    with {:ok, input} <- Pages.validate_create(input),
         {:ok, adf} <- markdown_to_adf(input.markdown),
         {:ok, space} <- Spaces.resolve(input.space_key, request) do
      payload =
        %{
          "spaceId" => space.id,
          "status" => "current",
          "title" => input.title,
          "body" => adf_body(adf)
        }
        |> maybe_put("parentId", input.parent_id)

      request
      |> Transport.request(mutation?: true)
      |> Req.post(url: Request.url(request, "/api/v2/pages"), json: payload)
      |> normalize_effect("create", nil, nil, space.id)
    end
  end

  def update(input, %Request{} = request) do
    with {:ok, input} <- Pages.validate_update(input),
         {:ok, adf} <- markdown_to_adf(input.markdown),
         {:ok, remote} <- fetch_metadata(input.id, request),
         :ok <- check_version(input, remote.version),
         {:ok, space} <- Spaces.resolve(input.space_key, request),
         :ok <- check_space(input, remote.space_id, space.id) do
      next_version = remote.version + 1

      version =
        %{"number" => next_version}
        |> maybe_put("message", input.version_message)

      payload = %{
        "id" => input.id,
        "status" => "current",
        "title" => input.title || remote.title,
        "body" => adf_body(adf),
        "version" => version
      }

      request
      |> Transport.request(mutation?: true)
      |> Req.put(
        url: Request.url(request, "/api/v2/pages/#{path_segment(input.id)}"),
        json: payload
      )
      |> normalize_effect("update", input.id, next_version, space.id)
    end
  end

  def delete(input, %Request{} = request) do
    with {:ok, %{id: id}} <- Pages.validate_delete(input) do
      response =
        request
        |> Transport.request(mutation?: true)
        |> Req.delete(url: Request.url(request, "/api/v2/pages/#{path_segment(id)}"))

      case response do
        {:ok, %{status: 204}} ->
          Normalizer.delete_effect(id)

        {:ok, %{status: status, body: body}} when status in 200..299 ->
          Transport.invalid_success_response("Confluence page delete response was invalid", body,
            mutation?: true
          )

        other ->
          Transport.handle_error_response(other,
            message: "Confluence page delete request failed",
            mutation?: true
          )
      end
    end
  end

  defp fetch_raw(request, id) do
    request
    |> Transport.request()
    |> Req.get(
      url: Request.url(request, "/api/v2/pages/#{path_segment(id)}"),
      params: %{"body-format" => "atlas_doc_format"}
    )
  end

  defp fetch_metadata(id, request) do
    response =
      request
      |> Transport.request()
      |> Req.get(url: Request.url(request, "/api/v2/pages/#{path_segment(id)}"))

    case response do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
        case Normalizer.page_metadata(body, id) do
          {:ok, result} ->
            {:ok, result}

          :error ->
            Transport.invalid_success_response("Confluence page response was invalid", body)
        end

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        Transport.invalid_success_response("Confluence page response was invalid", body)

      other ->
        Transport.handle_error_response(other, message: "Confluence page request failed")
    end
  end

  defp normalize_list({:ok, %{status: status, body: body}}, space, request, limit)
       when status in 200..299 and is_map(body) do
    context = %{account: Request.account(request), site_url: request.endpoint, limit: limit}

    case Normalizer.page_list(body, space, context) do
      {:ok, result} ->
        {:ok, result}

      :error ->
        Transport.invalid_success_response("Confluence page list response was invalid", body)
    end
  end

  defp normalize_list({:ok, %{status: status, body: body}}, _space, _request, _limit)
       when status in 200..299,
       do: Transport.invalid_success_response("Confluence page list response was invalid", body)

  defp normalize_list(response, _space, _request, _limit) do
    Transport.handle_error_response(response, message: "Confluence page list request failed")
  end

  defp normalize_page({:ok, %{status: status, body: body}}, id, max_characters, request)
       when status in 200..299 and is_map(body) do
    case Normalizer.page(body, id, max_characters, %{account: Request.account(request)}) do
      {:ok, result} -> {:ok, result}
      :error -> Transport.invalid_success_response("Confluence page response was invalid", body)
    end
  end

  defp normalize_page({:ok, %{status: status, body: body}}, _id, _maximum, _request)
       when status in 200..299,
       do: Transport.invalid_success_response("Confluence page response was invalid", body)

  defp normalize_page(response, _id, _maximum, _request) do
    Transport.handle_error_response(response, message: "Confluence page request failed")
  end

  defp normalize_effect({:ok, %{status: status, body: body}}, effect, id, version, space_id)
       when status in 200..299 and is_map(body) do
    case Normalizer.page_effect(body, effect, id, version, space_id) do
      {:ok, result} ->
        {:ok, result}

      :error ->
        Transport.invalid_success_response("Confluence page #{effect} response was invalid", body,
          mutation?: true
        )
    end
  end

  defp normalize_effect({:ok, %{status: status, body: body}}, effect, _id, _version, _space_id)
       when status in 200..299 do
    Transport.invalid_success_response("Confluence page #{effect} response was invalid", body,
      mutation?: true
    )
  end

  defp normalize_effect(response, effect, _id, _version, _space_id) do
    Transport.handle_error_response(response,
      message: "Confluence page #{effect} request failed",
      mutation?: true
    )
  end

  defp check_version(%{force: true}, _remote_version), do: :ok

  defp check_version(%{last_pushed_version: expected, id: id}, remote_version)
       when expected != remote_version do
    {:error,
     Error.provider("Confluence page version conflict",
       provider: :confluence,
       reason: :version_conflict,
       delivery: :response_received,
       mutation?: false,
       details: %{page_id: id, last_pushed_version: expected, remote_version: remote_version}
     )}
  end

  defp check_version(_input, _remote_version), do: :ok

  defp check_space(input, remote_space_id, expected_space_id)
       when remote_space_id != expected_space_id do
    {:error,
     Error.provider("Confluence page is in a different space",
       provider: :confluence,
       reason: :space_mismatch,
       delivery: :response_received,
       mutation?: false,
       details: %{page_id: input.id, space_key: input.space_key}
     )}
  end

  defp check_space(_input, _remote_space_id, _expected_space_id), do: :ok

  defp markdown_to_adf(markdown) do
    case ADF.from_markdown(markdown) do
      {:ok, adf} ->
        {:ok, adf}

      :error ->
        {:error,
         Error.validation("Invalid Confluence Markdown",
           reason: :invalid_confluence_markdown,
           subject: :markdown
         )}
    end
  end

  defp adf_body(adf) do
    %{"representation" => "atlas_doc_format", "value" => Jason.encode!(adf)}
  end

  defp path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
