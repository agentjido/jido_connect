defmodule Jido.Connect.Nextcloud.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud.Normalizer

  @dav_response """
  <?xml version="1.0"?>
  <d:multistatus xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns" xmlns:ocs="http://open-collaboration-services.org/ns">
    <d:response>
      <d:href>/remote.php/dav/files/alice/Documents/</d:href>
      <d:propstat>
        <d:prop>
          <d:displayname>Documents</d:displayname>
          <d:resourcetype><d:collection /></d:resourcetype>
          <oc:fileid>10</oc:fileid>
          <oc:size>1024</oc:size>
          <oc:permissions>RDNVCK</oc:permissions>
          <oc:owner-id>alice</oc:owner-id>
          <oc:favorite>1</oc:favorite>
          <oc:share-types><oc:share-type>3</oc:share-type></oc:share-types>
          <ocs:share-permissions>31</ocs:share-permissions>
          <nc:has-preview>true</nc:has-preview>
        </d:prop>
      </d:propstat>
    </d:response>
    <d:response>
      <d:href>/remote.php/dav/files/alice/Documents/report.txt</d:href>
      <d:propstat>
        <d:prop>
          <d:displayname>report.txt</d:displayname>
          <d:getcontenttype>text/plain</d:getcontenttype>
          <d:getetag>&quot;abc&quot;</d:getetag>
          <d:getlastmodified>Tue, 18 Jun 2026 12:00:00 GMT</d:getlastmodified>
          <oc:fileid>11</oc:fileid>
          <oc:size>42</oc:size>
        </d:prop>
      </d:propstat>
    </d:response>
  </d:multistatus>
  """

  test "normalizes WebDAV nodes" do
    assert {:ok, [folder, file]} = Normalizer.dav_nodes(@dav_response, login_name: "alice")

    assert folder.path == "/Documents/"
    assert folder.name == "Documents"
    assert folder.type == :folder
    assert folder.file_id == "10"
    assert folder.size == 1024
    assert folder.favorite? == true
    assert folder.share_types == [3]
    assert folder.share_permissions == 31
    assert folder.has_preview? == true

    assert file.path == "/Documents/report.txt"
    assert file.type == :file
    assert file.content_type == "text/plain"
    assert file.etag == "abc"
  end

  test "normalizes OCS share JSON" do
    body = %{
      "ocs" => %{
        "meta" => %{"statuscode" => "100"},
        "data" => [
          %{
            "id" => 123,
            "path" => "/report.txt",
            "share_type" => 3,
            "permissions" => 1,
            "url" => "https://cloud.example.com/s/abc"
          }
        ]
      }
    }

    assert {:ok, data} = Normalizer.ocs_data(body)
    assert {:ok, [share]} = Normalizer.shares(data)
    assert share.share_id == "123"
    assert share.path == "/report.txt"
    assert share.share_type == 3
    assert share.permissions == 1
  end

  test "normalizes OCS share XML" do
    xml = """
    <?xml version="1.0"?>
    <ocs>
      <meta><status>ok</status><statuscode>100</statuscode><message>OK</message></meta>
      <data>
        <element>
          <id>123</id>
          <path>/report.txt</path>
          <share_type>3</share_type>
          <permissions>1</permissions>
        </element>
      </data>
    </ocs>
    """

    assert {:ok, data} = Normalizer.ocs_data(xml)
    assert {:ok, [share]} = Normalizer.shares(data)
    assert share.share_id == "123"
    assert share.path == "/report.txt"
  end

  test "normalizes sharees and office capabilities" do
    data = %{
      "users" => [
        %{
          "label" => "Alice",
          "shareType" => 0,
          "value" => %{"shareWith" => "alice", "name" => "Alice"}
        }
      ]
    }

    assert {:ok, [sharee]} = Normalizer.sharees(data)
    assert sharee.id == "alice"
    assert sharee.label == "Alice"
    assert sharee.type == 0

    assert %{available?: true} =
             Normalizer.office_capabilities(%{"richdocuments" => %{"version" => "11.0.0"}})

    assert %{available?: true, supports_external_apps?: true} =
             Normalizer.office_capabilities(%{
               "capabilities" => %{
                 "richdocuments" => %{"version" => "11.0.0", "external_apps" => true}
               }
             })

    assert %{available?: false} = Normalizer.office_capabilities(%{})
  end
end
