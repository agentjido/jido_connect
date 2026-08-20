defmodule Jido.Connect.ConfluenceTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Confluence
  alias Jido.Connect.Error

  defmodule NoCallClient do
    alias Jido.Connect.Confluence.Input.{Pages, Spaces}

    def get_space(input, _request), do: validate(Spaces.validate_get(input))
    def list_pages(input, _request), do: validate(Pages.validate_list(input))
    def get_page(input, _request), do: validate(Pages.validate_get(input))
    def create_page(input, _request), do: validate(Pages.validate_create(input))
    def update_page(input, _request), do: validate(Pages.validate_update(input))
    def delete_page(input, _request), do: validate(Pages.validate_delete(input))

    defp validate({:error, error}), do: {:error, error}

    defp validate({:ok, _input}) do
      send(self(), :unexpected_confluence_call)
      {:error, :unexpected_call}
    end
  end

  @action_contract %{
    "confluence.space.get" => {:space, :get, :read, :none},
    "confluence.page.list" => {:page, :list, :read, :none},
    "confluence.page.get" => {:page, :get, :read, :none},
    "confluence.page.create" => {:page, :create, :write, :required_for_ai},
    "confluence.page.update" => {:page, :update, :write, :required_for_ai},
    "confluence.page.delete" => {:page, :delete, :destructive, :always}
  }

  test "declares the six reviewed Confluence actions and distinct provider identity" do
    spec = Confluence.integration()

    assert spec.id == :confluence
    assert spec.package == :jido_connect_confluence
    assert spec.name == "Confluence"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.triggers == []

    assert Map.new(spec.actions, fn action ->
             {action.id, {action.resource, action.verb, action.risk, action.confirmation}}
           end) == @action_contract

    assert Enum.all?(spec.actions, &(&1.provider_idempotency? == false))

    assert [%{id: :api_token, kind: :api_key} = profile] = spec.auth_profiles
    assert profile.default?
    assert profile.credential_fields == [:email, :api_token]
    assert profile.lease_fields == [:email, :api_token]
  end

  test "publishes bounded snake-case schemas and reviewed confirmations" do
    actions = Map.new(Confluence.integration().actions, &{&1.id, &1})

    space_fields = fields(actions["confluence.space.get"])
    assert_bound(space_fields.key, 1, 255)

    list_fields = fields(actions["confluence.page.list"])
    assert_bound(list_fields.space_key, 1, 255)
    assert_bound(list_fields.cursor, 1, 2048)
    assert list_fields.limit.minimum == 1
    assert list_fields.limit.maximum == 250
    assert list_fields.limit.default == 25

    get_fields = fields(actions["confluence.page.get"])
    assert_bound(get_fields.id, 1, 255)
    assert get_fields.max_characters.minimum == 1
    assert get_fields.max_characters.maximum == 100_000
    assert get_fields.max_characters.default == 20_000

    create_fields = fields(actions["confluence.page.create"])
    assert create_fields.title.required?
    assert create_fields.space_key.required?
    assert create_fields.markdown.required?
    assert_bound(create_fields.title, 1, 255)
    assert_bound(create_fields.space_key, 1, 255)
    assert_bound(create_fields.markdown, 0, 100_000)
    assert_bound(create_fields.parent_id, 1, 255)

    update_fields = fields(actions["confluence.page.update"])
    assert update_fields.id.required?
    assert update_fields.space_key.required?
    assert update_fields.markdown.required?
    assert update_fields.last_pushed_version.minimum == 1
    assert update_fields.force.default == false
    assert_bound(update_fields.title, 1, 255)
    assert_bound(update_fields.version_message, 1, 255)

    assert actions["confluence.page.delete"].preview ==
             Jido.Connect.Confluence.Previews.DeletePage
  end

  test "registers generated modules and package discovery" do
    assert Application.get_env(:jido_connect_confluence, :jido_connect_providers) == [Confluence]

    assert Confluence.jido_action_modules() == [
             Jido.Connect.Confluence.Actions.GetSpace,
             Jido.Connect.Confluence.Actions.ListPages,
             Jido.Connect.Confluence.Actions.GetPage,
             Jido.Connect.Confluence.Actions.CreatePage,
             Jido.Connect.Confluence.Actions.UpdatePage,
             Jido.Connect.Confluence.Actions.DeletePage
           ]

    assert Confluence.jido_sensor_modules() == []
    assert Confluence.jido_plugin_module() == Jido.Connect.Confluence.Plugin

    assert %Connect.Catalog.Manifest{id: :confluence, package: :jido_connect_confluence} =
             Confluence.jido_connect_manifest()

    for module <- Confluence.jido_action_modules() do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
    end
  end

  test "publishes separate reader, editor, and destructive packs" do
    [reader, editor, destructive] = Confluence.catalog_packs()

    assert reader.id == :confluence_reader

    assert reader.allowed_tools == [
             "confluence.space.get",
             "confluence.page.list",
             "confluence.page.get"
           ]

    assert editor.id == :confluence_editor
    assert "confluence.page.create" in editor.allowed_tools
    assert "confluence.page.update" in editor.allowed_tools
    refute "confluence.page.delete" in editor.allowed_tools

    assert destructive.id == :confluence_destructive
    assert destructive.allowed_tools == ["confluence.page.delete"]

    assert Enum.all?([reader, editor, destructive], &(&1.filters == %{provider: :confluence}))
  end

  test "generated action executes through the injected client" do
    runtime = Jido.Connect.Confluence.TestRuntime.build()

    assert {:ok, %{kind: "confluence_space", id: "space-1", key: "OPS"}} =
             Connect.invoke(
               Confluence,
               "confluence.space.get",
               %{key: "OPS"},
               runtime_opts(runtime)
             )

    assert_received :confluence_get_space
  end

  test "thin handlers delegate all reviewed actions to the injected client" do
    runtime = Jido.Connect.Confluence.TestRuntime.build()

    assert {:ok, %{kind: "confluence_pages"}} =
             Jido.Connect.Confluence.Handlers.Actions.ListPages.run(
               %{space_key: "OPS"},
               runtime
             )

    assert_received {:confluence_list_pages, [limit: 25, cursor: nil]}

    assert {:ok, %{kind: "confluence_page", id: "page-1"}} =
             Jido.Connect.Confluence.Handlers.Actions.GetPage.run(%{id: "page-1"}, runtime)

    assert_received {:confluence_get_page, [max_characters: 20_000]}

    assert {:ok, %{effect: "create"}} =
             Jido.Connect.Confluence.Handlers.Actions.CreatePage.run(
               %{title: "Runbook", space_key: "OPS", markdown: "text"},
               runtime
             )

    assert_received {:confluence_create_page, [parent_id: nil]}

    assert {:ok, %{effect: "update"}} =
             Jido.Connect.Confluence.Handlers.Actions.UpdatePage.run(
               %{
                 id: "page-1",
                 space_key: "OPS",
                 markdown: "text",
                 last_pushed_version: 4
               },
               runtime
             )

    assert_received {:confluence_update_page, [force: false, title: nil, version_message: nil]}

    assert {:ok, %{effect: "delete"}} =
             Jido.Connect.Confluence.Handlers.Actions.DeletePage.run(%{id: "page-1"}, runtime)

    assert_received :confluence_delete_page
  end

  test "runtime bounds reject unsafe values at the injected client boundary" do
    runtime = Jido.Connect.Confluence.TestRuntime.build(provider_client: NoCallClient)

    invalid_calls = [
      {"confluence.space.get", %{key: String.duplicate("K", 256)}},
      {"confluence.page.list", %{space_key: "OPS", limit: 0}},
      {"confluence.page.list", %{space_key: "OPS", limit: 251}},
      {"confluence.page.list", %{space_key: "OPS", cursor: String.duplicate("c", 2049)}},
      {"confluence.page.get", %{id: "page-1", max_characters: 0}},
      {"confluence.page.get", %{id: "page-1", max_characters: 100_001}},
      {"confluence.page.create",
       %{title: "Runbook", space_key: "OPS", markdown: String.duplicate("x", 100_001)}},
      {"confluence.page.update",
       %{id: "page-1", space_key: "OPS", markdown: "text", last_pushed_version: 0}},
      {"confluence.page.delete", %{id: String.duplicate("1", 256)}}
    ]

    for {action, input} <- invalid_calls do
      assert {:error, %Error.ValidationError{}} =
               Connect.invoke(Confluence, action, input, runtime_opts(runtime))
    end

    refute_received :unexpected_confluence_call
  end

  test "delete preview contains only the selected page and operation" do
    assert Jido.Connect.Confluence.Previews.DeletePage.preview(%{id: "page-1"}, %{}) == %{
             operation: "delete_page",
             page_id: "page-1"
           }
  end

  test "write previews are bounded summaries and contract constants stay centralized" do
    assert Jido.Connect.Confluence.Previews.CreatePage.preview(
             %{title: "Runbook", space_key: "OPS", markdown: "text", parent_id: "parent-1"},
             %{}
           ) == %{
             operation: "create_page",
             title: "Runbook",
             space_key: "OPS",
             parent_id: "parent-1",
             markdown_characters: 4
           }

    assert Jido.Connect.Confluence.Previews.UpdatePage.preview(
             %{
               id: "page-1",
               space_key: "OPS",
               markdown: "changed",
               last_pushed_version: 4,
               force: true,
               title: "New title",
               version_message: "Sync"
             },
             %{}
           ) == %{
             operation: "update_page",
             page_id: "page-1",
             space_key: "OPS",
             last_pushed_version: 4,
             force: true,
             title: "New title",
             version_message: "Sync",
             markdown_characters: 7
           }

    assert Jido.Connect.Confluence.Previews.CreatePage.preview(%{markdown: nil}, %{}) == %{
             operation: "create_page",
             title: nil,
             space_key: nil,
             parent_id: nil,
             markdown_characters: 0
           }

    assert Jido.Connect.Confluence.Previews.UpdatePage.preview(%{markdown: %{}}, %{}) == %{
             operation: "update_page",
             page_id: nil,
             space_key: nil,
             last_pushed_version: nil,
             force: false,
             title: nil,
             version_message: nil,
             markdown_characters: 0
           }

    contract = Jido.Connect.Confluence.Contract
    assert contract.maximum_identifier_length() == 255
    assert contract.maximum_title_length() == 255
    assert contract.maximum_markdown_length() == 100_000
    assert contract.maximum_cursor_length() == 2_048
    assert contract.maximum_version_message_length() == 255
    assert contract.default_limit() == 25
    assert contract.maximum_limit() == 250
    assert contract.default_max_characters() == 20_000
    assert contract.maximum_max_characters() == 100_000

    assert Jido.Connect.Confluence.Client.resolve(%{}) == Jido.Connect.Confluence.Client
  end

  defp fields(action), do: Map.new(action.input, &{&1.name, &1})

  defp assert_bound(field, minimum, maximum) do
    assert field.min_length == minimum
    assert field.max_length == maximum
  end

  defp runtime_opts(runtime) do
    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    [context: runtime.context, credential_lease: lease, provider_client: runtime.provider_client]
  end
end
