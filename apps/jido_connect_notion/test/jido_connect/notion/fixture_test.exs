defmodule Jido.Connect.Notion.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion.Normalizer

  # ---------------------------------------------------------------------------
  # Page fixtures
  # ---------------------------------------------------------------------------

  describe "page fixtures" do
    test "normalizes common page fixture" do
      payload = fixture!("page_common.json")

      assert {:ok, page} = Normalizer.page(payload)
      assert page.id == "page-001"
      assert page.archived == false
      assert page.url == "https://www.notion.so/page-001"
      assert page.parent["type"] == "workspace"
      assert page.properties["title"]["type"] == "title"

      title_rt = page.properties["title"]["title"]
      assert length(title_rt) == 1
      assert Enum.at(title_rt, 0)["plain_text"] == "Project Roadmap"

      assert page.cover["type"] == "external"
      assert page.icon["emoji"] == "📋"
    end

    test "page fixture does not expose raw content bytes" do
      payload = fixture!("page_common.json")
      {:ok, page} = Normalizer.page(payload)
      page_map = Map.from_struct(page)

      refute Map.has_key?(page_map, :content)
      refute inspect(page) =~ "raw-content-should-not-map"
    end
  end

  # ---------------------------------------------------------------------------
  # Database fixtures
  # ---------------------------------------------------------------------------

  describe "database fixtures" do
    test "normalizes common database fixture" do
      payload = fixture!("database_common.json")

      assert {:ok, db} = Normalizer.database(payload)
      assert db.id == "db-001"
      assert length(db.title) == 1
      assert Enum.at(db.title, 0)["plain_text"] == "Engineering Tasks"
      assert length(db.description) == 1
      assert db.is_inline == false
      assert db.parent["type"] == "page_id"
      assert db.parent["page_id"] == "page-001"

      prop_names = db.properties |> Map.keys() |> MapSet.new()
      assert MapSet.member?(prop_names, "title")
      assert MapSet.member?(prop_names, "Status")
      assert MapSet.member?(prop_names, "Assignee")
      assert MapSet.member?(prop_names, "Due Date")

      assert db.icon["emoji"] == "🏗️"
    end
  end

  # ---------------------------------------------------------------------------
  # Block fixtures
  # ---------------------------------------------------------------------------

  describe "block fixtures" do
    test "normalizes common paragraph block fixture" do
      payload = fixture!("block_common.json")

      assert {:ok, block} = Normalizer.block(payload)
      assert block.id == "block-001"
      assert block.type == "paragraph"
      assert block.has_children == false
      assert block.archived == false
      assert block.parent["page_id"] == "page-001"
      assert length(block.rich_text) == 1
      assert Enum.at(block.rich_text, 0)["plain_text"] == "This is the project overview."
      assert block.paragraph["color"] == "default"
    end

    test "normalizes block with children fixture" do
      payload = fixture!("block_with_children.json")

      assert {:ok, block} = Normalizer.block(payload)
      assert block.id == "block-002"
      assert block.type == "heading_2"
      assert block.has_children == true
      assert length(block.children) == 1
      assert length(block.rich_text) == 1
      assert Enum.at(block.rich_text, 0)["plain_text"] == "Section Title"
    end
  end

  # ---------------------------------------------------------------------------
  # Rich text fixtures
  # ---------------------------------------------------------------------------

  describe "rich text fixtures" do
    test "normalizes text rich text fixture" do
      payload = fixture!("rich_text_text.json")

      assert {:ok, rt} = Normalizer.rich_text(payload)
      assert rt.type == "text"
      assert rt.plain_text == "Hello, world!"
      assert rt.text["content"] == "Hello, world!"
      assert rt.annotations["bold"] == false
    end

    test "normalizes mention rich text fixture" do
      payload = fixture!("rich_text_mention.json")

      assert {:ok, rt} = Normalizer.rich_text(payload)
      assert rt.type == "mention"
      assert rt.plain_text == "@Alice Nakamura"
      assert rt.mention["type"] == "user"
      assert rt.mention["user"]["id"] == "user-001"
    end
  end

  # ---------------------------------------------------------------------------
  # User fixtures
  # ---------------------------------------------------------------------------

  describe "user fixtures" do
    test "normalizes person user fixture" do
      payload = fixture!("user_person.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == "user-001"
      assert user.type == "person"
      assert user.name == "Alice Nakamura"
      assert user.avatar_url == "https://example.com/avatar.png"
      assert user.person["email"] == "alice@example.com"
    end

    test "normalizes bot user fixture" do
      payload = fixture!("user_bot.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == "user-002"
      assert user.type == "bot"
      assert user.name == "Integration Bot"
      assert user.bot["owner"]["type"] == "workspace"
      assert user.bot["workspace_name"] == "Acme Corp"
    end
  end

  # ---------------------------------------------------------------------------
  # Comment fixtures
  # ---------------------------------------------------------------------------

  describe "comment fixtures" do
    test "normalizes common comment fixture" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.id == "comment-001"
      assert comment.discussion_id == "discussion-001"
      assert comment.created_by["name"] == "Alice Nakamura"
      assert length(comment.rich_text) == 1
      assert Enum.at(comment.rich_text, 0)["plain_text"] == "This looks good to ship."
      assert comment.parent["page_id"] == "page-001"
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination fixtures
  # ---------------------------------------------------------------------------

  describe "pagination fixtures" do
    test "normalizes search results pagination" do
      payload = fixture!("search_results.json")

      assert {:ok, pagination} = Normalizer.pagination(payload)
      assert pagination.has_more == true
      assert pagination.next_cursor == "cursor-page-003"
    end

    test "normalizes empty pagination fixture" do
      payload = fixture!("pagination_empty.json")

      assert {:ok, pagination} = Normalizer.pagination(payload)
      assert pagination.has_more == false
      assert pagination.next_cursor == nil
    end

    test "normalizes pages from search results" do
      payload = fixture!("search_results.json")

      results = payload["results"]
      assert length(results) == 2

      assert {:ok, first} = Normalizer.page(Enum.at(results, 0))
      assert first.id == "page-001"

      assert {:ok, second} = Normalizer.page(Enum.at(results, 1))
      assert second.id == "page-002"
    end
  end

  # ---------------------------------------------------------------------------
  # Privacy fixture review
  # ---------------------------------------------------------------------------

  describe "privacy fixture review" do
    alias Jido.Connect.Sanitizer

    test "fixtures do not contain sensitive credential keys" do
      sensitive_keys = [
        "access_token",
        "api_key",
        "authorization",
        "client_secret",
        "password",
        "private_key",
        "refresh_token",
        "secret",
        "signing_secret",
        "token"
      ]

      fixtures =
        Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "notion", "*.json"])
        |> Path.wildcard()

      for path <- fixtures do
        json = File.read!(path)
        decoded = Jason.decode!(json)
        all_keys = collect_keys(decoded)

        for sensitive <- sensitive_keys do
          refute sensitive in all_keys,
                 "Fixture #{Path.basename(path)} contains sensitive key: #{sensitive}"
        end
      end
    end

    test "sanitizer handles all fixture structs without error" do
      fixtures_and_normalizers = [
        {"page_common.json", &Normalizer.page/1},
        {"database_common.json", &Normalizer.database/1},
        {"block_common.json", &Normalizer.block/1},
        {"comment_common.json", &Normalizer.comment/1},
        {"user_person.json", &Normalizer.user/1},
        {"user_bot.json", &Normalizer.user/1},
        {"pagination_empty.json", &Normalizer.pagination/1}
      ]

      for {file, normalizer} <- fixtures_and_normalizers do
        payload = fixture!(file)
        {:ok, struct} = normalizer.(payload)
        sanitized = Sanitizer.sanitize(struct, :telemetry)
        assert is_map(sanitized), "Sanitizer failed for #{file}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "notion", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end

  defp collect_keys(value) when is_map(value) do
    value
    |> Enum.flat_map(fn {k, v} -> [k | collect_keys(v)] end)
  end

  defp collect_keys(value) when is_list(value) do
    Enum.flat_map(value, &collect_keys/1)
  end

  defp collect_keys(_value), do: []
end
