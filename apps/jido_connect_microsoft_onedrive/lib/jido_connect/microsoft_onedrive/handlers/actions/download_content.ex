defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DownloadContent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.DriveTarget

  @doc """
  Downloads the binary content of a Microsoft OneDrive drive item.

  Uses the Microsoft Graph `GET /me/drive/items/{id}/content` endpoint which
  may return binary content directly, redirect to a `@microsoft.graph.downloadUrl`,
  or return a JSON body with `@microsoft.graph.downloadUrl`.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :item_id) do
      nil ->
        {:error, :item_id_required}

      item_id ->
        with {:ok, url} <- DriveTarget.content(input, item_id) do
          request = Transport.request(access_token)

          case Transport.request(request, :get, url: url) do
            {:ok, %{status: 200, body: body, headers: headers}}
            when is_binary(body) ->
              {:ok, normalize_content(body, headers, item_id)}

            {:ok, %{status: 200, body: body}} when is_map(body) ->
              # Some items return metadata with @microsoft.graph.downloadUrl
              download_url = get_download_url(body)

              case download_url do
                nil ->
                  Transport.invalid_success_response(
                    "Microsoft OneDrive download response missing content",
                    body
                  )

                _url ->
                  Transport.invalid_success_response(
                    "Microsoft OneDrive download response missing binary content",
                    body
                  )
              end

            {:ok, response} ->
              Transport.handle_error_response({:ok, response},
                message: "Failed to download Microsoft OneDrive item content"
              )

            {:error, _reason} = error ->
              Transport.handle_error_response(error,
                message: "Failed to download Microsoft OneDrive item content"
              )
          end
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp get_download_url(body) when is_map(body) do
    Map.get(body, "@microsoft.graph.downloadUrl") ||
      Map.get(body, "@content.downloadUrl")
  end

  defp normalize_content(body, headers, item_id) do
    mime_type = response_mime_type(headers)
    is_binary = !text_content?(body)

    base = %{
      item_id: item_id,
      mime_type: mime_type,
      size: byte_size(body),
      content: if(not is_binary, do: body, else: nil),
      content_base64: if(is_binary, do: Base.encode64(body), else: nil),
      encoding: if(is_binary, do: "base64", else: "utf-8"),
      binary: is_binary
    }

    # Only compact the optional keys, not the content fields
    base
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp text_content?(content) do
    String.valid?(content) and :binary.match(content, <<0>>) == :nomatch
  end

  defp response_mime_type(headers) do
    headers
    |> header_value("content-type")
    |> strip_content_type_params()
  end

  defp header_value(headers, name) when is_map(headers) do
    case Map.get(headers, name) do
      nil -> header_value(headers, String.downcase(name))
      value -> extract_header_value(value)
    end
  end

  defp header_value(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: extract_header_value(value)

      _other ->
        nil
    end)
  end

  defp header_value(_headers, _name), do: nil

  defp extract_header_value([value | _rest]), do: to_string(value)
  defp extract_header_value(value), do: to_string(value)

  defp strip_content_type_params(value) when is_binary(value) do
    value
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp strip_content_type_params(_value), do: nil
end
