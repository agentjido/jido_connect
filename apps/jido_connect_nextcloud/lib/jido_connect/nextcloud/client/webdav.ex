defmodule Jido.Connect.Nextcloud.Client.WebDAV do
  @moduledoc "Nextcloud WebDAV client."

  alias Jido.Connect.Nextcloud.Client.{Path, Transport}

  @propfind_body """
  <?xml version="1.0" encoding="UTF-8"?>
  <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns">
    <d:prop>
      <d:displayname />
      <d:getcontenttype />
      <d:getcontentlength />
      <d:getetag />
      <d:getlastmodified />
      <d:resourcetype />
      <oc:fileid />
      <oc:size />
      <oc:permissions />
      <oc:owner-id />
      <oc:owner-display-name />
      <oc:favorite />
      <oc:share-types />
      <ocs:share-permissions xmlns:ocs="http://open-collaboration-services.org/ns" />
      <nc:has-preview />
      <nc:note />
    </d:prop>
  </d:propfind>
  """

  def propfind(credentials, path, opts \\ []) do
    request = Transport.request(credentials, accept: "application/xml")

    Transport.request(request, :propfind,
      url: Path.files_url(credentials.login_name, path),
      body: @propfind_body,
      headers: [
        {"content-type", "application/xml"},
        {"depth", Keyword.get(opts, :depth, "1")}
      ]
    )
  end

  def search(credentials, query, opts \\ []) do
    request = Transport.request(credentials, accept: "application/xml")
    scope_path = Keyword.get(opts, :scope_path, "/")

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <d:searchrequest xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns">
      <d:basicsearch>
        <d:select>
          <d:prop>
            <oc:fileid />
            <d:displayname />
            <d:getcontenttype />
            <d:getetag />
            <d:getlastmodified />
            <oc:size />
          </d:prop>
        </d:select>
        <d:from>
          <d:scope>
            <d:href>/files/#{escape_xml(credentials.login_name)}#{escape_xml(Path.normalize(scope_path))}</d:href>
            <d:depth>infinity</d:depth>
          </d:scope>
        </d:from>
        <d:where>
          <d:like>
            <d:prop><d:displayname /></d:prop>
            <d:literal>%#{escape_xml(query)}%</d:literal>
          </d:like>
        </d:where>
        <d:orderby />
      </d:basicsearch>
    </d:searchrequest>
    """

    Transport.request(request, :search,
      url: "/remote.php/dav/",
      body: body,
      headers: [{"content-type", "text/xml"}]
    )
  end

  def download(credentials, path) do
    request = Transport.request(credentials, accept: "*/*")
    Transport.request(request, :get, url: Path.files_url(credentials.login_name, path))
  end

  def mkcol(credentials, path) do
    request = Transport.request(credentials, accept: "application/xml")
    Transport.request(request, :mkcol, url: Path.files_url(credentials.login_name, path))
  end

  def upload(credentials, path, content, opts \\ []) do
    request = Transport.request(credentials, accept: "application/xml")

    Transport.request(request, :put,
      url: Path.files_url(credentials.login_name, path),
      body: content,
      headers: [{"content-type", Keyword.get(opts, :content_type, "application/octet-stream")}]
    )
  end

  def move(credentials, from_path, to_path, opts \\ []) do
    request = Transport.request(credentials, accept: "application/xml")

    Transport.request(request, :move,
      url: Path.files_url(credentials.login_name, from_path),
      headers: destination_headers(credentials, to_path, opts)
    )
  end

  def copy(credentials, from_path, to_path, opts \\ []) do
    request = Transport.request(credentials, accept: "application/xml")

    Transport.request(request, :copy,
      url: Path.files_url(credentials.login_name, from_path),
      headers: destination_headers(credentials, to_path, opts)
    )
  end

  def delete(credentials, path) do
    request = Transport.request(credentials, accept: "application/xml")
    Transport.request(request, :delete, url: Path.files_url(credentials.login_name, path))
  end

  defp destination_headers(credentials, to_path, opts) do
    [
      {"destination",
       Path.destination_url(credentials.base_url, credentials.login_name, to_path)},
      {"overwrite", if(Keyword.get(opts, :overwrite, false), do: "T", else: "F")}
    ]
  end

  defp escape_xml(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
