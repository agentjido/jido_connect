defmodule Jido.Connect.Nextcloud.Client.XMLTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud.Client.XML

  test "parses namespaced XML into local-name tree" do
    assert {:ok, doc} =
             XML.parse_document("""
             <d:multistatus xmlns:d="DAV:">
               <d:response>
                 <d:href>/remote.php/dav/files/alice/report.txt</d:href>
                 <d:prop><d:displayname>report.txt</d:displayname></d:prop>
               </d:response>
             </d:multistatus>
             """)

    assert doc.local_name == "multistatus"
    assert [response] = XML.elements_by_name(doc, "response")
    assert XML.child_text(response, "href") == "/remote.php/dav/files/alice/report.txt"
    assert XML.deep_text(response, "displayname") == "report.txt"
    assert XML.child_text(response, "missing", "fallback") == "fallback"
    assert XML.find_deep(response, "missing") == nil
  end

  test "returns errors and empty results for invalid input" do
    assert {:error, :invalid_xml} = XML.parse_document(nil)
    assert XML.children(%{}, "response") == []
    assert XML.elements_by_name(nil, "response") == []
    assert XML.find_deep(nil, "response") == nil
  end
end
