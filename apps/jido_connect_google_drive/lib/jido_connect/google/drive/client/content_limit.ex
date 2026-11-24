defmodule Jido.Connect.Google.Drive.Client.ContentLimit do
  @moduledoc """
  The optional byte limit `max_bytes` of Drive file content reads.

  `Jido.Connect.Google.Drive.Client.export_file/2` and
  `Jido.Connect.Google.Drive.Client.download_file/2` hold the whole body in
  memory. This module gives both reads a count of the bytes received and
  gives the download a check of the declared size.

  The count runs while the body arrives. `receive_options/1` hands Req an
  `:into` callback that stops reading before it collects the byte that would
  exceed the limit, and `check_received/1` turns the stopped response into
  the limit error. A `content-length` above the limit stops the read at the
  first chunk. A body of exactly `max_bytes` bytes passes and is returned as
  without a limit.

  Before a download, `check_declared_size/2` compares the `size` from Drive's
  `files.get` with `max_bytes`. A file declared larger than the limit fails
  without a content request. A Google Workspace document passes, because
  Drive reports a `size` for it but refuses its download, and so does a file
  without a `size` or with one that is not a whole number. The count still
  applies to their content. An export has no such check, because Drive's
  `size` does not describe an export.

  A read stopped at the limit returns a `Jido.Connect.Error.ProviderError`
  with reason `:limit_exceeded` and `details.max_bytes`. It carries none of
  the bytes read so far, and `Jido.Connect.Error.retryable?/1` is `false` for
  it, because a repeated read meets the same limit.

  The count covers the bytes Drive sends, which are the bytes the action
  returns: Req neither asks for nor decompresses an encoded body when `:into`
  is set. Bodies of non-2xx responses, such as Google's JSON errors, do not
  count against `max_bytes` and are read as without a limit.
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Drive.Client.Transport

  @exceeded :google_drive_max_bytes_exceeded

  @doc """
  Returns the `max_bytes` of `params`: `{:ok, nil}` without one, `{:ok, n}`
  for a non-negative integer, otherwise a `ValidationError` with reason
  `:invalid_max_bytes`.
  """
  def max_bytes(params) do
    case Data.get(params, :max_bytes) do
      nil ->
        {:ok, nil}

      max_bytes when is_integer(max_bytes) and max_bytes >= 0 ->
        {:ok, max_bytes}

      _invalid ->
        {:error,
         Error.validation("Google Drive max_bytes must be a non-negative integer",
           reason: :invalid_max_bytes,
           subject: :max_bytes
         )}
    end
  end

  @doc "Req options that count the body against `max_bytes`; none without a limit."
  def receive_options(nil), do: []
  def receive_options(max_bytes), do: [into: &collect(&1, &2, max_bytes)]

  @doc "Turns a response stopped at the limit into the limit error."
  def check_received({:ok, %Req.Response{private: %{@exceeded => max_bytes}}}),
    do: {:error, limit_exceeded(max_bytes)}

  def check_received(_result), do: :ok

  @doc """
  Checks the `size` that Drive's `files.get` declares for a file against
  `max_bytes`, before the content is requested.

  A file without a usable `size` passes, and so does a Google Workspace
  document, whose `size` Drive reports although it has no bytes to download.
  A failed metadata read returns its provider error.
  """
  def check_declared_size({:ok, %{status: status, body: body}}, max_bytes)
      when status in 200..299,
      do: check_size(body, max_bytes)

  def check_declared_size(response, _max_bytes), do: Transport.handle_error_response(response)

  defp check_size(%{"mimeType" => "application/vnd.google-apps." <> _type}, _max_bytes), do: :ok

  defp check_size(%{"size" => size}, max_bytes) when is_binary(size) do
    case Integer.parse(size) do
      {declared, ""} when declared > max_bytes -> {:error, limit_exceeded(max_bytes)}
      _within_limit_or_unusable -> :ok
    end
  end

  defp check_size(_without_size, _max_bytes), do: :ok

  defp collect({:data, data}, {request, %Req.Response{status: status} = response}, max_bytes)
       when status in 200..299 do
    if declared_length_exceeds?(response, max_bytes) or
         byte_size(response.body) + byte_size(data) > max_bytes do
      response = Req.Response.put_private(%{response | body: ""}, @exceeded, max_bytes)
      {:halt, {request, response}}
    else
      {:cont, {request, %{response | body: response.body <> data}}}
    end
  end

  # Error and redirect bodies, such as Google's JSON errors, are kept whole,
  # as without a limit.
  defp collect({:data, data}, {request, response}, _max_bytes),
    do: {:cont, {request, %{response | body: response.body <> data}}}

  defp declared_length_exceeds?(response, max_bytes) do
    case Req.Response.get_header(response, "content-length") do
      [length] -> match?({declared, ""} when declared > max_bytes, Integer.parse(length))
      _absent_or_repeated -> false
    end
  end

  defp limit_exceeded(max_bytes) do
    Error.provider("Google Drive file content exceeds max_bytes",
      provider: :google,
      reason: :limit_exceeded,
      delivery: :response_received,
      details: %{max_bytes: max_bytes}
    )
  end
end
