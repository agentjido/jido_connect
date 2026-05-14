defmodule Jido.Connect.Google.Drive.Client.Response do
  @moduledoc "Google Drive response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Drive.{Client.Transport, Normalizer}

  def handle_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, files} <-
           normalize_items(
             body,
             "files",
             &Normalizer.file/1,
             "Google Drive file list response was invalid"
           ) do
      {:ok,
       %{
         files: files,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file list response was invalid", body)
  end

  def handle_file_list_response(response), do: Transport.handle_error_response(response)

  def handle_file_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.file/1, "Google Drive file response was invalid")
  end

  def handle_file_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file response was invalid", body)
  end

  def handle_file_response(response), do: Transport.handle_error_response(response)

  def handle_file_content_response({:ok, %{status: status, body: body, headers: headers}}, params)
      when status in 200..299 and is_binary(body) do
    {:ok, normalize_file_content(body, headers, params)}
  end

  def handle_file_content_response({:ok, %{status: status, body: body}}, _params)
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive file content response was invalid", body)
  end

  def handle_file_content_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_file_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       file_id: Data.get(params, :file_id),
       deleted?: true
     }}
  end

  def handle_file_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_permission_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, permissions} <-
           normalize_items(
             body,
             "permissions",
             &Normalizer.permission/1,
             "Google Drive permission list response was invalid"
           ) do
      {:ok,
       %{
         permissions: permissions,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_permission_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive permission list response was invalid", body)
  end

  def handle_permission_list_response(response), do: Transport.handle_error_response(response)

  def handle_permission_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.permission/1, "Google Drive permission response was invalid")
  end

  def handle_permission_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive permission response was invalid", body)
  end

  def handle_permission_response(response), do: Transport.handle_error_response(response)

  def handle_permission_delete_response({:ok, %{status: status}}, params)
      when status in 200..299 do
    {:ok,
     %{
       file_id: Data.get(params, :file_id),
       permission_id: Data.get(params, :permission_id),
       deleted?: true
     }}
  end

  def handle_permission_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_revision_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, revisions} <-
           normalize_items(
             body,
             "revisions",
             &Normalizer.revision/1,
             "Google Drive revision list response was invalid"
           ) do
      {:ok,
       %{
         revisions: revisions,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_revision_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive revision list response was invalid", body)
  end

  def handle_revision_list_response(response), do: Transport.handle_error_response(response)

  def handle_revision_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.revision/1, "Google Drive revision response was invalid")
  end

  def handle_revision_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive revision response was invalid", body)
  end

  def handle_revision_response(response), do: Transport.handle_error_response(response)

  def handle_revision_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       file_id: Data.get(params, :file_id),
       revision_id: Data.get(params, :revision_id),
       deleted?: true
     }}
  end

  def handle_revision_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_start_page_token_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "startPageToken") do
      token when is_binary(token) ->
        {:ok, %{start_page_token: token}}

      _missing ->
        Transport.invalid_success_response(
          "Google Drive start page token response was invalid",
          body
        )
    end
  end

  def handle_start_page_token_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive start page token response was invalid", body)
  end

  def handle_start_page_token_response(response), do: Transport.handle_error_response(response)

  def handle_change_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, changes} <-
           normalize_items(
             body,
             "changes",
             &Normalizer.change/1,
             "Google Drive change list response was invalid"
           ) do
      {:ok,
       %{
         changes: changes,
         next_page_token: Data.get(body, "nextPageToken"),
         new_start_page_token: Data.get(body, "newStartPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_change_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive change list response was invalid", body)
  end

  def handle_change_list_response(response), do: Transport.handle_error_response(response)

  def handle_channel_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.channel/1, "Google Drive channel response was invalid")
  end

  def handle_channel_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Drive channel response was invalid", body)
  end

  def handle_channel_response(response), do: Transport.handle_error_response(response)

  def handle_channel_stop_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       channel_id: Data.get(params, :channel_id),
       resource_id: Data.get(params, :resource_id),
       stopped?: true
     }}
  end

  def handle_channel_stop_response(response, _params),
    do: Transport.handle_error_response(response)

  def file_to_folder({:ok, file}) do
    %{
      "id" => file.file_id,
      "name" => file.name,
      "webViewLink" => file.web_view_link,
      "createdTime" => file.created_time,
      "modifiedTime" => file.modified_time,
      "parents" => file.parents,
      "trashed" => file.trashed?,
      "shared" => file.shared?,
      "driveId" => file.drive_id
    }
    |> Normalizer.folder()
  end

  def file_to_folder({:error, reason}), do: {:error, reason}

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

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

  defp normalize_file_content(body, headers, params) do
    base = %{
      file_id: Data.get(params, :file_id),
      mime_type: Data.get(params, :mime_type) || response_mime_type(headers),
      size: byte_size(body)
    }

    content =
      if text_content?(body) do
        %{content: body, content_base64: nil, encoding: "utf-8", binary: false}
      else
        %{content: nil, content_base64: Base.encode64(body), encoding: "base64", binary: true}
      end

    base
    |> Map.merge(content)
    |> Data.compact()
  end

  defp text_content?(content) do
    String.valid?(content) and :binary.match(content, <<0>>) == :nomatch
  end

  defp response_mime_type(headers) do
    headers
    |> header("content-type")
    |> strip_content_type_params()
  end

  defp header(headers, name) when is_map(headers) do
    headers
    |> Map.get(name)
    |> header_value()
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: header_value(value)

      _other ->
        nil
    end)
  end

  defp header(_headers, _name), do: nil

  defp header_value([value | _rest]), do: value
  defp header_value(value), do: value

  defp strip_content_type_params(value) when is_binary(value) do
    value
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
  end

  defp strip_content_type_params(_value), do: nil
end
