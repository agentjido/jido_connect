defmodule Jido.Connect.Notion.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion.{
    Block,
    Comment,
    Database,
    File,
    Normalizer,
    Page,
    Pagination,
    ParentRef,
    Property,
    RichText,
    User
  }

  # ---------------------------------------------------------------------------
  # Parent reference
  # ---------------------------------------------------------------------------

  describe "parent_ref/1" do
    test "normalizes workspace parent" do
      assert {:ok, %ParentRef{} = ref} =
               Normalizer.parent_ref(%{"type" => "workspace", "workspace" => true})

      assert ref.type == "workspace"
      assert ref.workspace == true
    end

    test "normalizes page_id parent" do
      assert {:ok, %ParentRef{} = ref} =
               Normalizer.parent_ref(%{"type" => "page_id", "page_id" => "page-001"})

      assert ref.type == "page_id"
      assert ref.page_id == "page-001"
    end

    test "normalizes database_id parent" do
      assert {:ok, %ParentRef{} = ref} =
               Normalizer.parent_ref(%{"type" => "database_id", "database_id" => "db-001"})

      assert ref.type == "database_id"
      assert ref.database_id == "db-001"
    end

    test "normalizes block_id parent" do
      assert {:ok, %ParentRef{} = ref} =
               Normalizer.parent_ref(%{"type" => "block_id", "block_id" => "block-001"})

      assert ref.type == "block_id"
      assert ref.block_id == "block-001"
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_parent_ref_payload} = Normalizer.parent_ref("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Rich text
  # ---------------------------------------------------------------------------

  describe "rich_text/1" do
    test "normalizes text segment" do
      assert {:ok, %RichText{} = rt} =
               Normalizer.rich_text(%{
                 "type" => "text",
                 "text" => %{"content" => "Hello"},
                 "plain_text" => "Hello",
                 "annotations" => %{"bold" => true}
               })

      assert rt.type == "text"
      assert rt.plain_text == "Hello"
      assert rt.text["content"] == "Hello"
      assert rt.annotations["bold"] == true
    end

    test "normalizes mention segment" do
      assert {:ok, %RichText{} = rt} =
               Normalizer.rich_text(%{
                 "type" => "mention",
                 "mention" => %{"type" => "user"},
                 "plain_text" => "@Alice"
               })

      assert rt.type == "mention"
      assert rt.mention["type"] == "user"
    end

    test "normalizes equation segment" do
      assert {:ok, %RichText{} = rt} =
               Normalizer.rich_text(%{
                 "type" => "equation",
                 "equation" => %{"expression" => "e=mc^2"},
                 "plain_text" => "e=mc^2"
               })

      assert rt.type == "equation"
      assert rt.equation["expression"] == "e=mc^2"
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_rich_text_payload} = Normalizer.rich_text("not a map")
    end
  end

  describe "rich_text_list/1" do
    test "normalizes list of rich text segments" do
      segments = [
        %{"type" => "text", "text" => %{"content" => "Hello "}, "plain_text" => "Hello "},
        %{"type" => "text", "text" => %{"content" => "world"}, "plain_text" => "world"}
      ]

      assert {:ok, [%RichText{} | _] = list} = Normalizer.rich_text_list(segments)
      assert length(list) == 2
    end

    test "returns error for non-list input" do
      assert {:error, :invalid_rich_text_list_payload} = Normalizer.rich_text_list("not a list")
    end

    test "returns error when a segment is invalid" do
      segments = [%{"type" => "text", "plain_text" => "ok"}, "invalid"]

      assert {:error, _} = Normalizer.rich_text_list(segments)
    end
  end

  # ---------------------------------------------------------------------------
  # File
  # ---------------------------------------------------------------------------

  describe "file/1" do
    test "normalizes external file" do
      assert {:ok, %File{} = f} =
               Normalizer.file(%{
                 "type" => "external",
                 "name" => "diagram.png",
                 "external" => %{"url" => "https://example.com/diagram.png"}
               })

      assert f.type == "external"
      assert f.name == "diagram.png"
      assert f.url == "https://example.com/diagram.png"
      assert f.expiry_time == nil
    end

    test "normalizes hosted file with expiry" do
      assert {:ok, %File{} = f} =
               Normalizer.file(%{
                 "type" => "file",
                 "name" => "report.pdf",
                 "file" => %{
                   "url" => "https://example.com/hosted.pdf",
                   "expiry_time" => "2026-06-01T00:00:00Z"
                 }
               })

      assert f.type == "file"
      assert f.name == "report.pdf"
      assert f.url == "https://example.com/hosted.pdf"
      assert f.expiry_time == "2026-06-01T00:00:00Z"
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_file_payload} = Normalizer.file("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  describe "user/1" do
    test "normalizes person user" do
      assert {:ok, %User{} = u} =
               Normalizer.user(%{
                 "id" => "user-001",
                 "type" => "person",
                 "name" => "Alice Nakamura",
                 "avatar_url" => "https://example.com/avatar.png",
                 "person" => %{"email" => "alice@example.com"}
               })

      assert u.id == "user-001"
      assert u.type == "person"
      assert u.name == "Alice Nakamura"
      assert u.person["email"] == "alice@example.com"
    end

    test "normalizes bot user" do
      assert {:ok, %User{} = u} =
               Normalizer.user(%{
                 "id" => "user-002",
                 "type" => "bot",
                 "name" => "Integration Bot",
                 "bot" => %{"owner" => %{"type" => "workspace"}}
               })

      assert u.id == "user-002"
      assert u.type == "bot"
      assert u.name == "Integration Bot"
      assert u.bot["owner"]["type"] == "workspace"
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_user_payload} = Normalizer.user("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Property
  # ---------------------------------------------------------------------------

  describe "property/1" do
    test "normalizes title property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "title-prop",
                 "type" => "title",
                 "title" => [%{"plain_text" => "Project Roadmap"}]
               })

      assert p.type == "title"
      assert p.title == [%{"plain_text" => "Project Roadmap"}]
    end

    test "normalizes rich_text property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "rt-prop",
                 "type" => "rich_text",
                 "rich_text" => [%{"plain_text" => "Some text"}]
               })

      assert p.type == "rich_text"
    end

    test "normalizes number property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "num-prop",
                 "type" => "number",
                 "number" => 42.5
               })

      assert p.type == "number"
      assert p.number == 42.5
    end

    test "normalizes select property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "sel-prop",
                 "type" => "select",
                 "select" => %{"name" => "High", "color" => "red"}
               })

      assert p.type == "select"
      assert p.select["name"] == "High"
    end

    test "normalizes multi_select property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "ms-prop",
                 "type" => "multi_select",
                 "multi_select" => [%{"name" => "tag1"}, %{"name" => "tag2"}]
               })

      assert p.type == "multi_select"
      assert length(p.multi_select) == 2
    end

    test "normalizes date property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "date-prop",
                 "type" => "date",
                 "date" => %{"start" => "2026-05-01", "end" => nil}
               })

      assert p.type == "date"
      assert p.date["start"] == "2026-05-01"
    end

    test "normalizes checkbox property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{"id" => "cb-prop", "type" => "checkbox", "checkbox" => true})

      assert p.type == "checkbox"
      assert p.checkbox == true
    end

    test "normalizes url property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "url-prop",
                 "type" => "url",
                 "url" => "https://example.com"
               })

      assert p.type == "url"
      assert p.url == "https://example.com"
    end

    test "normalizes email property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "email-prop",
                 "type" => "email",
                 "email" => "alice@example.com"
               })

      assert p.type == "email"
      assert p.email == "alice@example.com"
    end

    test "normalizes phone_number property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "phone-prop",
                 "type" => "phone_number",
                 "phone_number" => "+1-555-0100"
               })

      assert p.type == "phone_number"
      assert p.phone_number == "+1-555-0100"
    end

    test "normalizes status property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "status-prop",
                 "type" => "status",
                 "status" => %{"name" => "In Progress", "color" => "blue"}
               })

      assert p.type == "status"
      assert p.status["name"] == "In Progress"
    end

    test "normalizes formula property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "formula-prop",
                 "type" => "formula",
                 "formula" => %{"type" => "number", "number" => 10}
               })

      assert p.type == "formula"
    end

    test "normalizes relation property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "rel-prop",
                 "type" => "relation",
                 "relation" => [%{"id" => "page-002"}]
               })

      assert p.type == "relation"
      assert length(p.relation) == 1
    end

    test "normalizes rollup property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "rollup-prop",
                 "type" => "rollup",
                 "rollup" => %{"type" => "number", "number" => 5}
               })

      assert p.type == "rollup"
    end

    test "normalizes people property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "people-prop",
                 "type" => "people",
                 "people" => [%{"id" => "user-001"}]
               })

      assert p.type == "people"
      assert length(p.people) == 1
    end

    test "normalizes files property" do
      assert {:ok, %Property{} = p} =
               Normalizer.property(%{
                 "id" => "files-prop",
                 "type" => "files",
                 "files" => [%{"name" => "doc.pdf", "type" => "external"}]
               })

      assert p.type == "files"
      assert length(p.files) == 1
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_property_payload} = Normalizer.property("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Block
  # ---------------------------------------------------------------------------

  describe "block/1" do
    test "normalizes paragraph block" do
      assert {:ok, %Block{} = b} =
               Normalizer.block(%{
                 "id" => "block-001",
                 "type" => "paragraph",
                 "created_time" => "2026-04-20T11:00:00.000Z",
                 "last_edited_time" => "2026-04-20T11:00:00.000Z",
                 "has_children" => false,
                 "archived" => false,
                 "parent" => %{"type" => "page_id", "page_id" => "page-001"},
                 "paragraph" => %{
                   "rich_text" => [
                     %{
                       "type" => "text",
                       "text" => %{"content" => "Hello"},
                       "plain_text" => "Hello"
                     }
                   ],
                   "color" => "default"
                 }
               })

      assert b.id == "block-001"
      assert b.type == "paragraph"
      assert b.has_children == false
      assert b.archived == false
      assert length(b.rich_text) == 1
      assert b.paragraph["color"] == "default"
    end

    test "normalizes heading block" do
      assert {:ok, %Block{} = b} =
               Normalizer.block(%{
                 "id" => "block-010",
                 "type" => "heading_1",
                 "heading_1" => %{
                   "rich_text" => [%{"plain_text" => "Title"}],
                   "color" => "default"
                 }
               })

      assert b.type == "heading_1"
      assert length(b.rich_text) == 1
    end

    test "normalizes block with children" do
      assert {:ok, %Block{} = b} =
               Normalizer.block(%{
                 "id" => "block-002",
                 "type" => "paragraph",
                 "has_children" => true,
                 "children" => [
                   %{"id" => "block-003", "type" => "paragraph"}
                 ]
               })

      assert b.has_children == true
      assert length(b.children) == 1
    end

    test "defaults has_children and archived to false" do
      assert {:ok, %Block{} = b} =
               Normalizer.block(%{"id" => "block-min", "type" => "divider", "divider" => %{}})

      assert b.has_children == false
      assert b.archived == false
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_block_payload} = Normalizer.block("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Page
  # ---------------------------------------------------------------------------

  describe "page/1" do
    test "normalizes page with all fields" do
      assert {:ok, %Page{} = p} =
               Normalizer.page(%{
                 "id" => "page-001",
                 "created_time" => "2026-04-15T10:00:00.000Z",
                 "last_edited_time" => "2026-05-10T14:30:00.000Z",
                 "archived" => false,
                 "in_trash" => false,
                 "url" => "https://www.notion.so/page-001",
                 "public_url" => nil,
                 "parent" => %{"type" => "workspace", "workspace" => true},
                 "properties" => %{
                   "title" => %{
                     "type" => "title",
                     "title" => [%{"plain_text" => "Project Roadmap"}]
                   }
                 },
                 "cover" => %{
                   "type" => "external",
                   "external" => %{"url" => "https://example.com/cover.jpg"}
                 },
                 "icon" => %{"type" => "emoji", "emoji" => "📋"}
               })

      assert p.id == "page-001"
      assert p.archived == false
      assert p.url == "https://www.notion.so/page-001"
      assert p.parent["type"] == "workspace"
      assert p.properties["title"]["type"] == "title"
      assert p.cover["type"] == "external"
      assert p.icon["emoji"] == "📋"
    end

    test "normalizes minimal page" do
      assert {:ok, %Page{} = p} =
               Normalizer.page(%{"id" => "page-min"})

      assert p.id == "page-min"
      assert p.properties == %{}
      assert p.children == []
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_page_payload} = Normalizer.page("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Database
  # ---------------------------------------------------------------------------

  describe "database/1" do
    test "normalizes database with all fields" do
      assert {:ok, %Database{} = db} =
               Normalizer.database(%{
                 "id" => "db-001",
                 "created_time" => "2026-03-01T09:00:00.000Z",
                 "last_edited_time" => "2026-05-12T16:00:00.000Z",
                 "title" => [%{"plain_text" => "Engineering Tasks"}],
                 "description" => [%{"plain_text" => "Tracking engineering work items"}],
                 "url" => "https://www.notion.so/db-001",
                 "is_inline" => false,
                 "parent" => %{"type" => "page_id", "page_id" => "page-001"},
                 "properties" => %{
                   "title" => %{"type" => "title"},
                   "Status" => %{"type" => "status"}
                 },
                 "icon" => %{"type" => "emoji", "emoji" => "🏗️"}
               })

      assert db.id == "db-001"
      assert db.is_inline == false
      assert length(db.title) == 1
      assert length(db.description) == 1
      assert db.parent["page_id"] == "page-001"
      assert db.icon["emoji"] == "🏗️"
    end

    test "normalizes minimal database" do
      assert {:ok, %Database{} = db} =
               Normalizer.database(%{"id" => "db-min"})

      assert db.id == "db-min"
      assert db.title == []
      assert db.description == []
      assert db.properties == %{}
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_database_payload} = Normalizer.database("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  describe "comment/1" do
    test "normalizes comment with rich text" do
      assert {:ok, %Comment{} = c} =
               Normalizer.comment(%{
                 "id" => "comment-001",
                 "discussion_id" => "discussion-001",
                 "created_time" => "2026-05-01T09:00:00.000Z",
                 "last_edited_time" => "2026-05-01T09:00:00.000Z",
                 "created_by" => %{"id" => "user-001", "name" => "Alice"},
                 "rich_text" => [%{"plain_text" => "Looks good"}],
                 "parent" => %{"type" => "page_id", "page_id" => "page-001"}
               })

      assert c.id == "comment-001"
      assert c.discussion_id == "discussion-001"
      assert c.created_by["name"] == "Alice"
      assert length(c.rich_text) == 1
      assert c.parent["page_id"] == "page-001"
    end

    test "normalizes minimal comment" do
      assert {:ok, %Comment{} = c} =
               Normalizer.comment(%{"id" => "comment-min"})

      assert c.id == "comment-min"
      assert c.rich_text == []
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_comment_payload} = Normalizer.comment("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  describe "pagination/1" do
    test "normalizes pagination with next cursor" do
      assert {:ok, %Pagination{} = p} =
               Normalizer.pagination(%{
                 "has_more" => true,
                 "next_cursor" => "cursor-abc123"
               })

      assert p.has_more == true
      assert p.next_cursor == "cursor-abc123"
    end

    test "normalizes terminal pagination" do
      assert {:ok, %Pagination{} = p} =
               Normalizer.pagination(%{"has_more" => false})

      assert p.has_more == false
      assert p.next_cursor == nil
    end

    test "defaults has_more to false" do
      assert {:ok, %Pagination{} = p} =
               Normalizer.pagination(%{})

      assert p.has_more == false
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_pagination_payload} = Normalizer.pagination("not a map")
    end
  end

  # ---------------------------------------------------------------------------
  # Struct constructors
  # ---------------------------------------------------------------------------

  describe "struct constructors expose schema defaults" do
    test "Page defaults" do
      page = Page.new!(%{id: "page-001"})
      assert page.archived == false
      assert page.properties == %{}
      assert page.children == []
      assert page.metadata == %{}

      assert {:error, _} = Page.new(%{})
    end

    test "Database defaults" do
      db = Database.new!(%{id: "db-001"})
      assert db.title == []
      assert db.description == []
      assert db.properties == %{}
      assert db.metadata == %{}
    end

    test "Block defaults" do
      block = Block.new!(%{id: "block-001"})
      assert block.has_children == false
      assert block.archived == false
      assert block.rich_text == []
      assert block.children == []
      assert block.metadata == %{}
    end

    test "RichText defaults" do
      rt = RichText.new!(%{})
      assert rt.type == "text"
      assert rt.metadata == %{}
    end

    test "User requires id" do
      user = User.new!(%{id: "user-001"})
      assert user.id == "user-001"
      assert user.metadata == %{}

      assert {:ok, _} = User.new(%{id: "user-001"})
    end

    test "Comment defaults" do
      comment = Comment.new!(%{id: "comment-001"})
      assert comment.rich_text == []
      assert comment.metadata == %{}
    end

    test "File requires type" do
      f = File.new!(%{type: "external"})
      assert f.type == "external"
      assert f.metadata == %{}
    end

    test "ParentRef requires type" do
      ref = ParentRef.new!(%{type: "workspace"})
      assert ref.type == "workspace"
      assert ref.metadata == %{}
    end

    test "Pagination defaults" do
      p = Pagination.new!(%{})
      assert p.has_more == false
      assert p.metadata == %{}
    end

    test "Property defaults" do
      prop = Property.new!(%{})
      assert prop.title == []
      assert prop.rich_text == []
      assert prop.multi_select == []
      assert prop.people == []
      assert prop.files == []
      assert prop.relation == []
      assert prop.metadata == %{}
    end
  end
end
