defmodule Jido.Connect.Asana.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.{
    CustomField,
    Normalizer,
    Pagination,
    Project,
    Section,
    Story,
    Tag,
    Task,
    User,
    Workspace
  }

  # ---------------------------------------------------------------------------
  # Workspace
  # ---------------------------------------------------------------------------

  test "normalizes workspace payloads" do
    assert {:ok, %Workspace{} = ws} =
             Normalizer.workspace(%{
               "gid" => "112233",
               "name" => "Acme Corp",
               "resource_type" => "workspace",
               "is_organization" => true,
               "email_domains" => ["acme.example.com"]
             })

    assert ws.gid == "112233"
    assert ws.name == "Acme Corp"
    assert ws.resource_type == "workspace"
    assert ws.is_organization == true
    assert ws.email_domains == ["acme.example.com"]
  end

  test "workspace normalizer tolerates missing optional fields" do
    assert {:ok, %Workspace{} = ws} =
             Normalizer.workspace(%{"gid" => "112234"})

    assert ws.gid == "112234"
    assert ws.name == nil
  end

  test "workspace normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.workspace("not a map")
    assert {:error, _error} = Normalizer.workspace(nil)
  end

  # ---------------------------------------------------------------------------
  # Project
  # ---------------------------------------------------------------------------

  test "normalizes project payloads" do
    assert {:ok, %Project{} = proj} =
             Normalizer.project(%{
               "gid" => "445566",
               "name" => "Website Redesign",
               "resource_type" => "project",
               "color" => "dark-green",
               "archived" => false,
               "public" => true,
               "due_on" => "2026-09-30",
               "start_on" => "2026-06-01",
               "notes" => "Full redesign of the marketing website",
               "default_view" => "board",
               "workspace" => %{"gid" => "112233", "name" => "Acme Corp"},
               "team" => %{"gid" => "778899", "name" => "Engineering"},
               "owner" => %{"gid" => "123456", "name" => "Alice Nakamura"},
               "created_at" => "2026-04-01T09:00:00.000Z",
               "modified_at" => "2026-05-15T11:30:00.000Z"
             })

    assert proj.gid == "445566"
    assert proj.name == "Website Redesign"
    assert proj.color == "dark-green"
    assert proj.archived == false
    assert proj.public == true
    assert proj.due_on == "2026-09-30"
    assert proj.start_on == "2026-06-01"
    assert proj.workspace_gid == "112233"
    assert proj.team_gid == "778899"
    assert proj.owner_gid == "123456"
  end

  test "project normalizer handles missing relational fields" do
    assert {:ok, %Project{} = proj} =
             Normalizer.project(%{"gid" => "445567"})

    assert proj.gid == "445567"
    assert proj.workspace_gid == nil
    assert proj.team_gid == nil
  end

  test "project normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.project("not a map")
  end

  # ---------------------------------------------------------------------------
  # Task
  # ---------------------------------------------------------------------------

  test "normalizes task payloads with assignee, projects, tags, and custom fields" do
    assert {:ok, %Task{} = task} =
             Normalizer.task(%{
               "gid" => "998877",
               "name" => "Design new landing page",
               "resource_type" => "task",
               "assignee" => %{
                 "gid" => "123456",
                 "name" => "Alice Nakamura"
               },
               "assignee_status" => "upcoming",
               "completed" => false,
               "due_on" => "2026-07-15",
               "due_at" => "2026-07-15T17:00:00.000Z",
               "start_on" => "2026-07-01",
               "notes" => "Create wireframes and visual designs",
               "num_hearts" => 3,
               "num_likes" => 5,
               "workspace" => %{"gid" => "112233"},
               "projects" => [
                 %{"gid" => "445566", "name" => "Website Redesign"}
               ],
               "tags" => [
                 %{"gid" => "556677", "name" => "design"}
               ],
               "memberships" => [
                 %{
                   "project" => %{"gid" => "445566"},
                   "section" => %{"gid" => "889900", "name" => "In Progress"}
                 }
               ],
               "custom_fields" => [
                 %{
                   "gid" => "667788",
                   "name" => "Priority",
                   "enum_value" => %{
                     "gid" => "771100",
                     "name" => "High"
                   }
                 },
                 %{
                   "gid" => "667789",
                   "name" => "Estimated Hours",
                   "number_value" => 16.0
                 }
               ],
               "created_at" => "2026-05-01T10:00:00.000Z",
               "modified_at" => "2026-05-18T14:30:00.000Z"
             })

    assert task.gid == "998877"
    assert task.name == "Design new landing page"
    assert task.assignee_gid == "123456"
    assert task.assignee_name == "Alice Nakamura"
    assert task.completed == false
    assert task.due_on == "2026-07-15"
    assert task.workspace_gid == "112233"
    assert "445566" in task.project_gids
    assert "556677" in task.tag_gids
    assert task.section_gid == "889900"

    # Custom fields extracted as map keyed by gid
    assert task.custom_fields["667788"].name == "Priority"
    assert task.custom_fields["667789"].name == "Estimated Hours"
  end

  test "task normalizer handles nil assignee" do
    assert {:ok, %Task{} = task} =
             Normalizer.task(%{
               "gid" => "998878",
               "assignee" => nil
             })

    assert task.gid == "998878"
    assert task.assignee_gid == nil
    assert task.assignee_name == nil
  end

  test "task normalizer handles empty projects and tags" do
    assert {:ok, %Task{} = task} =
             Normalizer.task(%{
               "gid" => "998879",
               "projects" => [],
               "tags" => []
             })

    assert task.project_gids == []
    assert task.tag_gids == []
  end

  test "task normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.task("not a map")
  end

  # ---------------------------------------------------------------------------
  # Section
  # ---------------------------------------------------------------------------

  test "normalizes section payloads" do
    assert {:ok, %Section{} = sec} =
             Normalizer.section(%{
               "gid" => "889900",
               "name" => "In Progress",
               "resource_type" => "section",
               "project" => %{"gid" => "445566", "name" => "Website Redesign"},
               "created_at" => "2026-04-01T09:00:00.000Z",
               "modified_at" => "2026-05-10T16:00:00.000Z"
             })

    assert sec.gid == "889900"
    assert sec.name == "In Progress"
    assert sec.project_gid == "445566"
  end

  test "section normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.section("not a map")
  end

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  test "normalizes user payloads" do
    assert {:ok, %User{} = u} =
             Normalizer.user(%{
               "gid" => "123456",
               "name" => "Alice Nakamura",
               "resource_type" => "user",
               "email" => "alice@example.com",
               "photo" => %{
                 "image_128x128" => "https://s3.amazonaws.com/photos/128.png"
               }
             })

    assert u.gid == "123456"
    assert u.name == "Alice Nakamura"
    assert u.email == "alice@example.com"
    assert u.photo["image_128x128"] == "https://s3.amazonaws.com/photos/128.png"
  end

  test "user normalizer handles missing email" do
    assert {:ok, %User{} = u} =
             Normalizer.user(%{"gid" => "123457"})

    assert u.gid == "123457"
    assert u.email == nil
  end

  test "user normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.user("not a map")
  end

  # ---------------------------------------------------------------------------
  # Story
  # ---------------------------------------------------------------------------

  test "normalizes story (comment) payloads" do
    assert {:ok, %Story{} = story} =
             Normalizer.story(%{
               "gid" => "334455",
               "resource_type" => "story",
               "resource_subtype" => "comment_added",
               "text" => "Updated the wireframes based on feedback.",
               "html_text" => "<body>Updated the wireframes based on feedback.</body>",
               "num_likes" => 2,
               "liked" => false,
               "created_by" => %{
                 "gid" => "123456",
                 "name" => "Alice Nakamura"
               },
               "target" => %{
                 "gid" => "998877",
                 "name" => "Design new landing page",
                 "resource_type" => "task"
               },
               "task" => %{"gid" => "998877"},
               "created_at" => "2026-05-15T09:30:00.000Z"
             })

    assert story.gid == "334455"
    assert story.resource_subtype == "comment_added"
    assert story.text == "Updated the wireframes based on feedback."
    assert story.num_likes == 2
    assert story.created_by["gid"] == "123456"
    assert story.target_gid == "998877"
    assert story.target_resource_type == "task"
    assert story.task_gid == "998877"
  end

  test "story normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.story("not a map")
  end

  # ---------------------------------------------------------------------------
  # Tag
  # ---------------------------------------------------------------------------

  test "normalizes tag payloads" do
    assert {:ok, %Tag{} = t} =
             Normalizer.tag(%{
               "gid" => "556677",
               "name" => "design",
               "resource_type" => "tag",
               "color" => "light-green",
               "notes" => "Design-related tasks",
               "workspace" => %{"gid" => "112233"},
               "created_at" => "2026-01-10T12:00:00.000Z"
             })

    assert t.gid == "556677"
    assert t.name == "design"
    assert t.color == "light-green"
    assert t.workspace_gid == "112233"
  end

  test "tag normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.tag("not a map")
  end

  # ---------------------------------------------------------------------------
  # CustomField
  # ---------------------------------------------------------------------------

  test "normalizes custom field payloads" do
    assert {:ok, %CustomField{} = cf} =
             Normalizer.custom_field(%{
               "gid" => "667788",
               "name" => "Priority",
               "resource_type" => "custom_field",
               "resource_subtype" => "enum",
               "type" => "enum",
               "description" => "Task priority level",
               "enabled" => true,
               "enum_options" => [
                 %{"gid" => "771100", "name" => "High", "color" => "red"},
                 %{"gid" => "771101", "name" => "Medium", "color" => "yellow"},
                 %{"gid" => "771102", "name" => "Low", "color" => "blue"}
               ],
               "workspace" => %{"gid" => "112233"},
               "created_at" => "2026-01-15T08:00:00.000Z"
             })

    assert cf.gid == "667788"
    assert cf.name == "Priority"
    assert cf.type == "enum"
    assert cf.description == "Task priority level"
    assert cf.enabled == true
    assert length(cf.enum_options) == 3
    assert cf.workspace_gid == "112233"
  end

  test "custom field normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.custom_field("not a map")
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  test "normalizes next_page envelope" do
    assert {:ok, %Pagination{} = page} =
             Normalizer.pagination(%{
               "next_page" => %{
                 "offset" => "eyJiIjoiIEP",
                 "path" => "/tasks?project=445566&offset=eyJiIjoiIEP",
                 "uri" => "https://app.asana.com/api/1.0/tasks?project=445566&offset=eyJiIjoiIEP"
               }
             })

    assert page.offset == "eyJiIjoiIEP"
    assert page.path == "/tasks?project=445566&offset=eyJiIjoiIEP"
    assert page.has_next == true
  end

  test "pagination normalizer handles missing next_page" do
    assert {:ok, %Pagination{} = page} = Normalizer.pagination(%{})

    assert page.offset == nil
    assert page.has_next == false
  end

  test "pagination normalizer rejects invalid payloads" do
    assert {:error, _error} = Normalizer.pagination("not a map")
  end

  # ---------------------------------------------------------------------------
  # Struct constructor contracts
  # ---------------------------------------------------------------------------

  test "struct constructors expose schema defaults and enforce required keys" do
    # Workspace
    assert {:error, _error} = Workspace.new(%{})

    assert %Workspace{} = ws = Workspace.new!(%{gid: "112233"})
    assert ws.metadata == %{}

    # Project
    assert {:error, _error} = Project.new(%{})

    assert %Project{} = proj = Project.new!(%{gid: "445566"})
    assert proj.metadata == %{}

    # Task
    assert {:error, _error} = Task.new(%{})

    assert %Task{} = task = Task.new!(%{gid: "998877"})
    assert task.project_gids == []
    assert task.tag_gids == []
    assert task.metadata == %{}

    # Section
    assert {:error, _error} = Section.new(%{})

    assert %Section{} = sec = Section.new!(%{gid: "889900"})
    assert sec.metadata == %{}

    # User
    assert {:error, _error} = User.new(%{})

    assert %User{} = u = User.new!(%{gid: "123456"})
    assert u.metadata == %{}

    # Story
    assert {:error, _error} = Story.new(%{})

    assert %Story{} = s = Story.new!(%{gid: "334455"})
    assert s.metadata == %{}

    # Tag
    assert {:error, _error} = Tag.new(%{})

    assert %Tag{} = t = Tag.new!(%{gid: "556677"})
    assert t.metadata == %{}

    # CustomField
    assert {:error, _error} = CustomField.new(%{})

    assert %CustomField{} = cf = CustomField.new!(%{gid: "667788"})
    assert cf.metadata == %{}

    # Pagination
    assert %Pagination{} = page = Pagination.new!(%{})
    assert page.metadata == %{}
  end

  test "struct modules expose schema/0" do
    for module <- [
          Workspace,
          Project,
          Task,
          Section,
          User,
          Story,
          Tag,
          CustomField,
          Pagination
        ] do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :schema, 0)
      assert module.schema()
    end
  end
end
