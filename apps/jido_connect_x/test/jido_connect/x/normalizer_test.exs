defmodule Jido.Connect.X.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.X.Normalizer

  @account %{id: "x-user-1", username: "mike_hostetler", name: "Mike Hostetler"}

  test "normalizes the strict account result family" do
    assert {:ok,
            %{
              kind: "social_account",
              id: "x-user-1",
              username: "Mike_Hostetler",
              name: "Mike Hostetler"
            }} =
             Normalizer.account(
               structured(%{
                 "data" => %{
                   "id" => "x-user-1",
                   "username" => "Mike_Hostetler",
                   "name" => "Mike Hostetler"
                 }
               })
             )
  end

  test "normalizes bookmark and post families with snake-case fields" do
    payload = %{
      "data" => [
        %{
          "id" => "post-1",
          "text" => "A saved post",
          "author_id" => "author-1",
          "created_at" => "2026-08-05T12:00:00.000Z"
        }
      ],
      "meta" => %{"next_token" => "cursor-2"}
    }

    for {action, kind} <- [
          {"x.bookmark.list", "social_bookmarks"},
          {"x.post.list", "social_posts"}
        ] do
      assert {:ok,
              %{
                kind: ^kind,
                account: %{kind: "social_account", id: "x-user-1"},
                count: 1,
                limit: 20,
                next_cursor: "cursor-2",
                items: [
                  %{
                    id: "post-1",
                    text: "A saved post",
                    url: "https://x.com/i/web/status/post-1",
                    author_id: "author-1",
                    created_at: "2026-08-05T12:00:00.000Z"
                  }
                ]
              }} = Normalizer.list(action, %{max_results: 20}, @account, structured(payload))
    end
  end

  test "accepts only structured content or one JSON text block" do
    account_payload = %{
      "data" => %{"id" => "x-user-1", "username" => "mike", "name" => "Mike"}
    }

    assert {:ok, %{id: "x-user-1"}} = Normalizer.account(structured(account_payload))

    assert {:ok, %{id: "x-user-1"}} =
             Normalizer.account(%{
               "content" => [%{"type" => "text", "text" => Jason.encode!(account_payload)}]
             })

    invalid = [
      %{},
      %{"structuredContent" => %{}},
      %{"content" => []},
      %{"content" => [%{"type" => "image", "data" => "secret-image"}]},
      %{
        "content" => [
          %{"type" => "text", "text" => "{}"},
          %{"type" => "text", "text" => "{}"}
        ]
      },
      %{"content" => [%{"type" => "text", "text" => "[]"}]},
      %{"content" => [%{"type" => "text", "text" => "{"}]}
    ]

    for result <- invalid do
      assert {:error, %Error.ProviderError{provider: :x, reason: :invalid_response}} =
               Normalizer.account(result)
    end
  end

  test "fails closed on malformed success and keeps error details secret-safe" do
    invalid_accounts = [
      %{"data" => %{"username" => "mike", "name" => "secret-account-name"}},
      %{"data" => %{"id" => "x-1", "username" => "@bad", "name" => "Mike"}},
      %{"data" => %{"id" => "x-1", "username" => "mike", "name" => ""}}
    ]

    for payload <- invalid_accounts do
      assert {:error, %Error.ProviderError{provider: :x, reason: :invalid_response} = error} =
               Normalizer.account(structured(payload))

      refute inspect(error) <> inspect(Error.to_map(error)) =~ "secret-account-name"
    end

    invalid_lists = [
      %{"data" => "secret-list"},
      %{"data" => [], "meta" => []},
      %{"data" => [%{"id" => "post-1"}]},
      %{"data" => [%{"id" => "post-1", "text" => 123}]},
      %{"data" => [%{"id" => "post-1", "text" => "text", "author_id" => 1}]},
      %{"data" => [], "meta" => %{"next_token" => ""}}
    ]

    for payload <- invalid_lists do
      assert {:error, %Error.ProviderError{provider: :x, reason: :invalid_response} = error} =
               Normalizer.list(
                 "x.bookmark.list",
                 %{max_results: 20},
                 @account,
                 structured(payload)
               )

      refute inspect(error) <> inspect(Error.to_map(error)) =~ "secret-list"
    end
  end

  defp structured(payload), do: %{"structuredContent" => payload}
end
