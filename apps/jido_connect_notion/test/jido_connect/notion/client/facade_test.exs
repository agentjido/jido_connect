defmodule Jido.Connect.Notion.ClientFacadeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion.Client

  test "delegates search to Client.Search" do
    assert Client.__info__(:functions)[:search] == 2
  end

  test "delegates get_page to Client.Pages" do
    assert Client.__info__(:functions)[:get_page] == 2
  end

  test "delegates get_database to Client.Databases" do
    assert Client.__info__(:functions)[:get_database] == 2
  end

  test "delegates query_database to Client.Databases" do
    assert Client.__info__(:functions)[:query_database] == 3
  end

  test "delegates retrieve_block to Client.Blocks" do
    assert Client.__info__(:functions)[:retrieve_block] == 2
  end

  test "delegates list_block_children to Client.Blocks" do
    assert Client.__info__(:functions)[:list_block_children] == 3
  end

  test "delegates list_comments to Client.Comments" do
    assert Client.__info__(:functions)[:list_comments] == 2
  end
end
