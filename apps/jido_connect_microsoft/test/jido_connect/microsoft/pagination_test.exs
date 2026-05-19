defmodule Jido.Connect.Microsoft.PaginationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.Pagination

  test "adds pagination options to query maps" do
    result = Pagination.query(%{q: "name"}, page_size: 50)
    assert result.q == "name"
    assert result[:"$top"] == 50

    result = Pagination.query(%{}, %{"page_size" => 25, "skip" => 10})
    assert result[:"$top"] == 25
    assert result[:"$skip"] == 10

    result = Pagination.query(%{q: "name"}, page_size: nil)
    assert result == %{q: "name"}
  end

  test "extracts next link, delta link, and checkpoint metadata" do
    body = %{"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10"}

    delta_body = %{
      "@odata.deltaLink" => "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc"
    }

    assert Pagination.next_link(body) ==
             "https://graph.microsoft.com/v1.0/me/messages?$skip=10"

    assert Pagination.next_link(:not_a_map) == nil

    assert Pagination.delta_link(delta_body) ==
             "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc"

    assert Pagination.delta_link(body) == nil

    assert Pagination.checkpoint(body, %{seen: 10}) == %{
             next_link: "https://graph.microsoft.com/v1.0/me/messages?$skip=10",
             seen: 10
           }
  end
end
