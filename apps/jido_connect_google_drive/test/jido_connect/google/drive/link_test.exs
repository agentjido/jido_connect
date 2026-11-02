defmodule Jido.Connect.Google.Drive.LinkTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error.ValidationError
  alias Jido.Connect.Google.Drive.Link

  doctest Link

  @id "1AbC-dEf_2gHiJkLmN0pQ"
  @other_id "1ZyX-wVu_9tSrQpOnM8lK"
  @key "0-AbCdEf_GhIjKl12345"
  @other_key "0-ZyXwVu_TsRqPo98765"
  # "Publish to the web" token: it follows `/d/e/` and names no file.
  @publish_token "2PACX-1vQAbCdEf_GhIjKl12345-ZyXwVu_TsRqPo98765"

  # Every shape of the spec, once without and once with a `resourcekey`.
  # Other query parameters and fragments are ignored.
  @shapes [
    "https://drive.google.com/file/d/#{@id}",
    "https://drive.google.com/file/d/#{@id}/view",
    "https://drive.google.com/file/d/#{@id}/edit",
    "https://drive.google.com/file/d/#{@id}/preview",
    "https://drive.google.com/open?id=#{@id}",
    "https://drive.google.com/drive/folders/#{@id}",
    "https://drive.google.com/drive/u/0/folders/#{@id}",
    "https://docs.google.com/document/d/#{@id}",
    "https://docs.google.com/document/d/#{@id}/edit",
    "https://docs.google.com/document/u/1/d/#{@id}/edit",
    "https://docs.google.com/spreadsheets/d/#{@id}/edit",
    "https://docs.google.com/spreadsheets/u/0/d/#{@id}/htmlview",
    "https://docs.google.com/presentation/d/#{@id}/edit",
    "https://docs.google.com/presentation/u/2/d/#{@id}/edit/slide"
  ]

  for shape <- @shapes do
    separator = if String.contains?(shape, "?"), do: "&", else: "?"

    test "parses #{shape} without a resource key" do
      url = unquote(shape) <> unquote(separator) <> "usp=sharing"

      assert {:ok, %{file_id: @id} = link} = Link.parse(url)
      refute Map.has_key?(link, :resource_key)
    end

    test "parses #{shape} with a resource key" do
      url = unquote(shape) <> unquote(separator) <> "usp=drivesdk&resourcekey=#{@key}"

      assert Link.parse(url) == {:ok, %{file_id: @id, resource_key: @key}}
    end
  end

  test "ignores fragments, a repeated identical ID and the host's letter case" do
    assert Link.parse(
             "https://docs.google.com/spreadsheets/d/#{@id}/edit?resourcekey=#{@key}#gid=0"
           ) ==
             {:ok, %{file_id: @id, resource_key: @key}}

    assert Link.parse("https://drive.google.com/open?id=#{@id}&id=#{@id}") ==
             {:ok, %{file_id: @id}}

    assert Link.parse("https://Drive.Google.com/file/d/#{@id}/view") == {:ok, %{file_id: @id}}
  end

  @rejected [
    {"http://drive.google.com/file/d/#{@id}/view?resourcekey=#{@key}", :unsupported_drive_link},
    {"http://docs.google.com/document/d/#{@id}/edit", :unsupported_drive_link},
    {"drive.google.com/file/d/#{@id}/view", :unsupported_drive_link},
    {"https://drive.google.com.example.org/file/d/#{@id}/view?resourcekey=#{@key}",
     :unsupported_drive_link},
    {"https://drive.google.com@example.org/file/d/#{@id}/view", :unsupported_drive_link},
    {"https://drive-google.com/file/d/#{@id}/view", :unsupported_drive_link},
    {"https://docs.google.com.example.org/document/d/#{@id}/edit", :unsupported_drive_link},
    {"https://www.google.com/file/d/#{@id}/view", :unsupported_drive_link},
    {"https://example.org/open?id=#{@id}", :unsupported_drive_link},
    {"https://drive.google.com", :unsupported_drive_link},
    {"https://drive.google.com/drive/my-drive", :unsupported_drive_link},
    {"https://drive.google.com/file/d/#{@id}/copy", :unsupported_drive_link},
    {"https://drive.google.com/drive/u/me/folders/#{@id}", :unsupported_drive_link},
    {"https://docs.google.com/document/u/me/d/#{@id}/edit", :unsupported_drive_link},
    {"https://docs.google.com/forms/d/#{@id}/edit", :unsupported_drive_link},
    {"https://docs.google.com/spreadsheets/d/e/#{@publish_token}/pubhtml",
     :unsupported_drive_link},
    {"https://docs.google.com/spreadsheets/d/e/#{@publish_token}/pub?output=csv",
     :unsupported_drive_link},
    {"https://docs.google.com/document/d/e/#{@publish_token}/pub", :unsupported_drive_link},
    {"https://docs.google.com/presentation/d/e/#{@publish_token}/pub?start=false",
     :unsupported_drive_link},
    {"https://docs.google.com/spreadsheets/u/0/d/e/#{@publish_token}/pubhtml?resourcekey=#{@key}",
     :unsupported_drive_link},
    {"https://drive.google.com/open", :missing_file_id},
    {"https://drive.google.com/open?id=&resourcekey=#{@key}", :missing_file_id},
    {"https://drive.google.com/open?id=ab%2Fcd", :missing_file_id},
    {"https://drive.google.com/file/d//view", :missing_file_id},
    {"https://docs.google.com/document/d/", :missing_file_id},
    {"https://drive.google.com/open?id=#{@id}&id=#{@other_id}&resourcekey=#{@key}",
     :conflicting_file_id},
    {"https://drive.google.com/file/d/#{@id}/view?id=#{@other_id}", :conflicting_file_id},
    {"https://drive.google.com/file/d/#{@id}/view?resourcekey=", :invalid_resource_key},
    {"https://drive.google.com/file/d/#{@id}/view?resourcekey=#{@key}&resourcekey=#{@other_key}",
     :invalid_resource_key},
    {"https://drive.google.com/file/d/#{@id}/view?resourcekey=#{@key}%0D%0A",
     :invalid_resource_key}
  ]

  for {url, reason} <- @rejected do
    test "rejects #{url} as #{reason}" do
      assert {:error, %ValidationError{reason: unquote(reason), subject: :url} = error} =
               Link.parse(unquote(url))

      refute inspect(error) =~ @key
    end
  end

  test "rejects values that are not URL strings" do
    for value <- [nil, 42, "", "not a url"] do
      assert {:error, %ValidationError{reason: :unsupported_drive_link}} = Link.parse(value)
    end
  end
end
