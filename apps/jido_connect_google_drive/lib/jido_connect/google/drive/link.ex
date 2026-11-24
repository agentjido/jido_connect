defmodule Jido.Connect.Google.Drive.Link do
  @moduledoc """
  Parses Google Drive and Google Docs links into a file ID and an optional
  resource key.

  The parser is pure: it never fetches the link. Accepted shapes, all `https`:

    * `drive.google.com/file/d/<id>`, optionally followed by `/view`, `/edit`
      or `/preview`
    * `drive.google.com/open?id=<id>`
    * `drive.google.com/drive/folders/<id>` and
      `drive.google.com/drive/u/<n>/folders/<id>`
    * `docs.google.com/{document,spreadsheets,presentation}/d/<id>/...` and the
      same with `/u/<n>` before `/d`

  "Publish to the web" links such as
  `docs.google.com/spreadsheets/d/e/<token>/pubhtml` carry a publish token
  instead of a file ID and are rejected as unsupported.

  The resource key comes from the `resourcekey` query parameter. Other query
  parameters and the fragment are ignored. The result uses the input names of
  `google.drive.file.get`, `google.drive.file.export` and
  `google.drive.file.download`, so it can be merged into their input:

      iex> Jido.Connect.Google.Drive.Link.parse(
      ...>   "https://drive.google.com/file/d/1AbC/view?usp=sharing&resourcekey=0-XyZ"
      ...> )
      {:ok, %{file_id: "1AbC", resource_key: "0-XyZ"}}

      iex> Jido.Connect.Google.Drive.Link.parse("https://drive.google.com/open?id=1AbC")
      {:ok, %{file_id: "1AbC"}}

  Other hosts, other shapes, `http`, missing or conflicting IDs and malformed
  or conflicting resource keys return a `Jido.Connect.Error.ValidationError`
  whose details never contain the link or its resource key.
  """

  alias Jido.Connect.Error

  @drive_host "drive.google.com"
  @docs_host "docs.google.com"
  @docs_editors ["document", "spreadsheets", "presentation"]
  @file_suffixes ["view", "edit", "preview"]
  @token ~r/\A[A-Za-z0-9_-]+\z/

  @type t :: %{required(:file_id) => String.t(), optional(:resource_key) => String.t()}

  @doc "Parses a Drive or Docs link into `%{file_id: ..., resource_key: ...}`."
  @spec parse(term()) :: {:ok, t()} | {:error, Error.ValidationError.t()}
  def parse(url) when is_binary(url) do
    with {:ok, uri} <- parse_uri(url),
         {:ok, path_id} <- path_id(host(uri), segments(uri.path)),
         query = query_values(uri.query),
         {:ok, file_id} <- file_id(path_id, Map.get(query, "id", [])),
         {:ok, resource_key} <- resource_key(Map.get(query, "resourcekey", [])) do
      {:ok, link(file_id, resource_key)}
    end
  end

  def parse(_url), do: unsupported("Google Drive link must be a URL string")

  defp parse_uri(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: "https", host: host} = uri} when is_binary(host) -> {:ok, uri}
      {:ok, %URI{scheme: "http"}} -> unsupported("Google Drive links must use https")
      _other -> unsupported("Google Drive link must be an absolute https URL")
    end
  end

  defp host(%URI{host: host}), do: String.downcase(host)

  defp segments("/" <> path), do: String.split(path, "/")
  defp segments(_path), do: []

  defp path_id(@drive_host, ["file", "d", id]), do: {:ok, id}

  defp path_id(@drive_host, ["file", "d", id, suffix]) when suffix in @file_suffixes,
    do: {:ok, id}

  defp path_id(@drive_host, ["open"]), do: {:ok, nil}
  defp path_id(@drive_host, ["drive", "folders", id]), do: {:ok, id}

  defp path_id(@drive_host, ["drive", "u", user, "folders", id]),
    do: with_user_index(user, id)

  # "Publish to the web" links put `e/<publish token>` after `/d/`. The token
  # names no file, so these links must not reach the ID clauses below.
  defp path_id(@docs_host, [editor, "d", "e" | _rest]) when editor in @docs_editors,
    do: unsupported_published()

  defp path_id(@docs_host, [editor, "u", _user, "d", "e" | _rest])
       when editor in @docs_editors,
       do: unsupported_published()

  defp path_id(@docs_host, [editor, "d", id | _rest]) when editor in @docs_editors,
    do: {:ok, id}

  defp path_id(@docs_host, [editor, "u", user, "d", id | _rest]) when editor in @docs_editors,
    do: with_user_index(user, id)

  defp path_id(host, _segments) when host in [@drive_host, @docs_host],
    do: unsupported("Google Drive link shape is not supported")

  defp path_id(_host, _segments), do: unsupported("Google Drive link host is not supported")

  defp with_user_index(user, id) do
    if user =~ ~r/\A\d+\z/,
      do: {:ok, id},
      else: unsupported("Google Drive link shape is not supported")
  end

  defp query_values(nil), do: %{}

  defp query_values(query) do
    query
    |> URI.query_decoder()
    |> Enum.group_by(fn {name, _value} -> name end, fn {_name, value} -> value end)
  end

  defp file_id(path_id, query_ids) do
    case Enum.uniq(List.wrap(path_id) ++ query_ids) do
      [id] -> if id =~ @token, do: {:ok, id}, else: missing_file_id()
      [] -> missing_file_id()
      _ids -> error(:conflicting_file_id, "Google Drive link names more than one file ID")
    end
  end

  defp resource_key(keys) do
    case Enum.uniq(keys) do
      [] -> {:ok, nil}
      [key] -> if key =~ @token, do: {:ok, key}, else: invalid_resource_key()
      _keys -> invalid_resource_key()
    end
  end

  defp link(file_id, nil), do: %{file_id: file_id}
  defp link(file_id, resource_key), do: %{file_id: file_id, resource_key: resource_key}

  defp missing_file_id, do: error(:missing_file_id, "Google Drive link has no file ID")

  defp invalid_resource_key,
    do:
      error(
        :invalid_resource_key,
        "Google Drive link has a malformed or conflicting resource key"
      )

  defp unsupported_published,
    do: unsupported("Published Google Docs links do not name a file and are not supported")

  defp unsupported(message), do: error(:unsupported_drive_link, message)

  defp error(reason, message),
    do: {:error, Error.validation(message, reason: reason, subject: :url)}
end
