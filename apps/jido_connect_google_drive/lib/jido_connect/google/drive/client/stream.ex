defmodule Jido.Connect.Google.Drive.Client.Stream do
  @moduledoc """
  Opt-in streaming of Drive file content.

  The caller supplies a non-negative `:max_bytes` and a synchronous `:collector`
  function taking each binary chunk and returning `:ok` or `{:error, reason}`.
  The collector owns its output and must discard partial output on any error or
  interruption. Calls execute in the caller process; collector work therefore
  applies backpressure. Successful responses return file ID, MIME type, HTTP
  status and the number of delivered bytes, without content in the result.

  Chunks are raw identity-encoded entity bytes. JSON and CSV are not decoded or
  normalized; callers that need the buffered API's decoded rows must do so
  themselves. Content-Length is only an early check; actual bytes are always
  counted. An optional caller-supplied `:declared_size` allows early rejection
  from Drive metadata, but is never used instead of counting. Compressed responses are rejected rather than comparing encoded and
  decoded sizes. HTTP error bodies are capped at 64 KiB. Retries are permitted
  for transient failures only before any successful body bytes reach a collector.
  On collector failure, cancellation or transport error the caller must clean up
  any partial output. Errors are normalized and do not expose collector reasons.

  `:req_options` is for trusted host configuration and isolated tests; it is not
  intended for user-supplied input. The stream's own limits and callbacks take
  precedence over these options.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Drive.Client.{Params, Transport}
  @error_cap 65_536
  @transient [408, 429, 500, 502, 503, 504]

  def download(%{file_id: id} = params, token, opts) when is_binary(id) and is_binary(token) do
    fetch(
      params,
      token,
      opts,
      "/v3/files/#{encode(id)}",
      Params.file_download_params(params),
      "*/*"
    )
  end

  def export(%{file_id: id, mime_type: mime} = params, token, opts)
      when is_binary(id) and is_binary(mime) and is_binary(token) do
    fetch(
      params,
      token,
      opts,
      "/v3/files/#{encode(id)}/export",
      Params.file_export_params(params),
      mime
    )
  end

  defp fetch(params, token, opts, url, query, accept) do
    limit = Keyword.get(opts, :max_bytes)
    collector = Keyword.get(opts, :collector)
    declared_size = Keyword.get(opts, :declared_size)

    cond do
      not (is_integer(limit) and limit >= 0 and is_function(collector, 1) and
               (is_nil(declared_size) or (is_integer(declared_size) and declared_size >= 0))) ->
        {:error, Error.validation("A non-negative max_bytes and collector function are required")}

      is_integer(declared_size) and declared_size > limit ->
        failure(:limit_exceeded)

      true ->
        key = {__MODULE__, make_ref()}
        Process.put(key, 0)

        try do
          result =
            token
            |> Transport.request()
            |> Req.merge(Keyword.get(opts, :req_options, []))
            |> Req.get(
              url: url,
              params: query,
              headers: [{"accept", accept}, {"accept-encoding", "identity"}],
              compressed: false,
              decode_body: false,
              retry: &retry?(key, &1, &2),
              into: callback(key, limit, collector)
            )

          finish(result, params, key, limit)
        after
          Process.delete(key)
        end
    end
  end

  defp callback(key, limit, collector) do
    fn {:data, data}, {request, response} ->
      if response.status in 200..299 do
        reason =
          cond do
            encoded?(response) -> :unsupported_encoding
            declared_length(response) > limit -> :limit_exceeded
            Process.get(key) + byte_size(data) > limit -> :limit_exceeded
            true -> nil
          end

        if reason do
          {:halt, {request, Req.Response.put_private(response, :stream_error, reason)}}
        else
          # Mark delivery before calling user code so a failure cannot lead to a retry.
          Process.put(key, Process.get(key) + byte_size(data))

          result =
            try do
              collector.(data)
            rescue
              _ -> {:error, :collector_failed}
            catch
              _, _ -> {:error, :collector_failed}
            end

          case result do
            :ok ->
              {:cont, {request, response}}

            _ ->
              {:halt,
               {request, Req.Response.put_private(response, :stream_error, :collector_failed)}}
          end
        end
      else
        body = response.body || ""
        remaining = max(@error_cap - byte_size(body), 0)
        part = binary_part(data, 0, min(byte_size(data), remaining))
        response = %{response | body: body <> part}

        if byte_size(data) > remaining,
          do: {:halt, {request, response}},
          else: {:cont, {request, response}}
      end
    end
  end

  defp finish({:ok, response}, params, key, limit) do
    cond do
      reason = response.private[:stream_error] ->
        failure(reason)

      response.status not in 200..299 ->
        body =
          case Jason.decode(response.body || "") do
            {:ok, decoded} -> decoded
            _ -> response.body
          end

        Transport.handle_error_response({:ok, %{response | body: body}})

      encoded?(response) ->
        failure(:unsupported_encoding)

      declared_length(response) > limit ->
        failure(:limit_exceeded)

      true ->
        mime =
          Map.get(params, :mime_type) ||
            response |> Req.Response.get_header("content-type") |> List.first() |> mime_type()

        {:ok,
         %{
           file_id: params.file_id,
           mime_type: mime,
           status: response.status,
           size: Process.get(key)
         }}
    end
  end

  defp finish(other, _params, _key, _limit), do: Transport.handle_error_response(other)

  defp failure(reason),
    do:
      {:error, Error.provider("Google Drive streaming failed", provider: :google, reason: reason)}

  defp mime_type(nil), do: nil
  defp mime_type(value), do: value |> String.split(";", parts: 2) |> hd() |> String.trim()
  defp encode(id), do: URI.encode(id, &URI.char_unreserved?/1)

  defp declared_length(response) do
    case Req.Response.get_header(response, "content-length") do
      [value] ->
        case Integer.parse(value) do
          {n, ""} when n >= 0 -> n
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp encoded?(response) do
    response
    |> Req.Response.get_header("content-encoding")
    |> Enum.any?(fn v -> String.downcase(String.trim(v)) not in ["", "identity"] end)
  end

  defp retry?(key, request, response) do
    Process.get(key) == 0 and request.method in [:get, :head] and transient?(response)
  end

  defp transient?(%Req.Response{status: status}), do: status in @transient

  defp transient?(%Req.TransportError{reason: reason}),
    do: reason in [:timeout, :econnrefused, :closed]

  defp transient?(%Req.HTTPError{protocol: :http2, reason: reason}),
    do: reason in [:unprocessed, :pool_not_available]

  defp transient?(_), do: false
end
