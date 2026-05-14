defmodule Jido.Connect.Google.Drive.FieldsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.Fields

  test "exposes Drive-specific field projection presets" do
    assert Fields.file_metadata() =~ "id,name,mimeType"
    assert Fields.permission_metadata() =~ "id,type,role,emailAddress"
    assert Fields.revision_metadata() =~ "id,mimeType,kind,published,keepForever"
    assert Fields.file_with_permissions() =~ "permissions(id,type,role,emailAddress"

    assert Fields.file_list() ==
             "nextPageToken,files(#{Fields.file_metadata()})"

    assert Fields.file_list_with_permissions() ==
             "nextPageToken,files(#{Fields.file_with_permissions()})"

    assert Fields.permission_list() ==
             "nextPageToken,permissions(#{Fields.permission_metadata()})"

    assert Fields.revision_list() ==
             "nextPageToken,revisions(#{Fields.revision_metadata()})"

    assert Fields.permission_views() == ["published"]
    assert Fields.file_presets().with_permissions == Fields.file_with_permissions()
    assert Fields.file_list_presets().with_permissions == Fields.file_list_with_permissions()
    assert Fields.permission_presets().default == Fields.permission_metadata()
    assert Fields.permission_list_presets().default == Fields.permission_list()
    assert Fields.revision_presets().default == Fields.revision_metadata()
    assert Fields.revision_list_presets().default == Fields.revision_list()
  end
end
