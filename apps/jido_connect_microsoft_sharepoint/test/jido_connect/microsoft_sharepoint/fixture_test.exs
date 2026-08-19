defmodule Jido.Connect.MicrosoftSharepoint.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftSharepoint.{Column, ListItem, Normalizer, Site, SiteList}

  test "normalizes SharePoint site metadata" do
    assert {:ok, %Site{} = site} = Normalizer.site(fixture!("site_common.json"))
    assert site.site_id == "contoso.sharepoint.com,site-collection-id,web-id"
    assert site.display_name == "Operations"
    assert site.site_collection["hostname"] == "contoso.sharepoint.com"
  end

  test "normalizes SharePoint list metadata" do
    assert {:ok, %SiteList{} = list} = Normalizer.site_list(fixture!("list_common.json"))
    assert list.list_id == "list-123"
    assert list.display_name == "Requests"
    assert list.list["template"] == "genericList"
  end

  test "normalizes SharePoint column metadata" do
    assert {:ok, %Column{} = column} = Normalizer.column(fixture!("column_common.json"))
    assert column.column_id == "column-123"
    assert column.column_type == "choice"
    assert column.settings["choices"] == ["Open", "Closed"]
    assert column.indexed
  end

  test "normalizes SharePoint list item fields and identities" do
    assert {:ok, %ListItem{} = item} = Normalizer.list_item(fixture!("list_item_common.json"))
    assert item.item_id == "42"
    assert item.etag == "\"42,3\""
    assert item.fields["Title"] == "Replace printer"
    assert item.created_by.user.email == "adele@contoso.com"
    refute item.deleted
  end

  test "normalizes pages and rejects malformed payloads" do
    envelope = %{
      "value" => [fixture!("list_item_common.json")],
      "@odata.nextLink" => "https://graph.microsoft.com/v1.0/next"
    }

    assert {:ok, %{items: [%ListItem{}], next_link: next_link}} =
             Normalizer.page(envelope, &Normalizer.list_item/1)

    assert next_link =~ "/next"
    assert {:error, :invalid_site_payload} = Normalizer.site(nil)
    assert {:error, :invalid_list_payloads} = Normalizer.normalize_list(:bad, &Normalizer.site/1)
  end

  defp fixture!(name) do
    [__DIR__, "..", "..", "fixtures", "microsoft_sharepoint", name]
    |> Path.join()
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
