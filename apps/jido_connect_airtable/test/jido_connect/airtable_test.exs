defmodule Jido.Connect.AirtableTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Airtable

  @airtable_action_modules [
    Jido.Connect.Airtable.Actions.ListBases,
    Jido.Connect.Airtable.Actions.GetBase,
    Jido.Connect.Airtable.Actions.ListTables,
    Jido.Connect.Airtable.Actions.ListRecords,
    Jido.Connect.Airtable.Actions.GetRecord,
    Jido.Connect.Airtable.Actions.CreateRecord,
    Jido.Connect.Airtable.Actions.UpdateRecord,
    Jido.Connect.Airtable.Actions.DeleteRecord,
    Jido.Connect.Airtable.Actions.CreateRecords,
    Jido.Connect.Airtable.Actions.UpdateRecords,
    Jido.Connect.Airtable.Actions.DeleteRecords
  ]

  @airtable_dsl_fragments [
    Jido.Connect.Airtable.Actions.Bases,
    Jido.Connect.Airtable.Actions.Records
  ]

  @test_scopes [
    "data.records:read",
    "data.records:write",
    "schema.bases:read",
    "schema.bases:write",
    "webhook:manage"
  ]

  test "declares Airtable provider metadata" do
    spec = Airtable.integration()

    assert spec.id == :airtable
    assert spec.package == :jido_connect_airtable
    assert spec.name == "Airtable"
    assert spec.category == :data
    assert spec.status == :experimental
    assert spec.tags == [:airtable, :database, :records, :bases]

    assert Enum.map(spec.actions, & &1.id) == [
             "airtable.bases.list",
             "airtable.bases.get",
             "airtable.tables.list",
             "airtable.records.list",
             "airtable.records.get",
             "airtable.records.create",
             "airtable.records.update",
             "airtable.records.delete",
             "airtable.records.batch_create",
             "airtable.records.batch_update",
             "airtable.records.batch_delete"
           ]

    assert spec.triggers == []

    assert [
             %{id: :personal_access_token, kind: :api_key} = pat_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert pat_profile.default? == true
    assert "data.records:read" in pat_profile.default_scopes
    assert "schema.bases:read" in pat_profile.default_scopes
    assert "data.records:write" in pat_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "data.records:read" in oauth_profile.default_scopes
    assert "schema.bases:read" in oauth_profile.default_scopes
    assert "data.records:write" in oauth_profile.optional_scopes
    assert "schema.bases:write" in oauth_profile.optional_scopes
    assert "webhook:manage" in oauth_profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_airtable, :jido_connect_providers) == [Airtable]

    assert Airtable.jido_action_modules() == @airtable_action_modules
    assert Airtable.jido_sensor_modules() == []
    assert Airtable.jido_plugin_module() == Jido.Connect.Airtable.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :airtable,
             package: :jido_connect_airtable,
             generated_modules: %{
               actions: @airtable_action_modules,
               sensors: [],
               plugin: Jido.Connect.Airtable.Plugin
             }
           } = Airtable.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "airtable",
             module: Jido.Connect.Airtable.Plugin,
             actions: @airtable_action_modules
           } = Jido.Connect.Airtable.Plugin.plugin_spec()
  end

  test "loads Airtable Spark DSL fragments" do
    for fragment <- @airtable_dsl_fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  test "exposes curated catalog pack delegates" do
    assert %{id: :airtable_reader} =
             Airtable.catalog_packs() |> Enum.find(&(&1.id == :airtable_reader))

    assert %{id: :airtable_editor} =
             Airtable.catalog_packs() |> Enum.find(&(&1.id == :airtable_editor))

    assert Enum.map(Airtable.catalog_packs(), & &1.id) == [
             :airtable_reader,
             :airtable_editor
           ]
  end

  test "invokes list bases through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{bases: [%{base_id: "appTest1", name: "Test Base"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.bases.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get base through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{base: %{base_id: "appTest1", name: "Test Base"}}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.bases.get",
               %{base_id: "appTest1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list tables through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{tables: [%{table_id: "tblTest1", name: "Tasks"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.tables.list",
               %{base_id: "appTest1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list records through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{records: [%{record_id: "rec1"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.list",
               %{base_id: "appTest1", table_id: "tblTest1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get record through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{record: %{record_id: "rec1", fields: %{"Name" => "Test"}}}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.get",
               %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create record through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{record: %{record_id: "rec2", fields: %{"Name" => "New"}}}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.create",
               %{base_id: "appTest1", table_id: "tblTest1", fields: %{"Name" => "New"}},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update record through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{record: %{record_id: "rec1", fields: %{"Name" => "Updated"}}}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.update",
               %{
                 base_id: "appTest1",
                 table_id: "tblTest1",
                 record_id: "rec1",
                 fields: %{"Name" => "Updated"}
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete record through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{record: %{record_id: "rec1"}}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.delete",
               %{base_id: "appTest1", table_id: "tblTest1", record_id: "rec1"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch create records through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{records: [%{record_id: "rec2"}, %{record_id: "rec3"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.batch_create",
               %{
                 base_id: "appTest1",
                 table_id: "tblTest1",
                 records: [%{"Name" => "New 1"}, %{"Name" => "New 2"}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch update records through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{records: [%{record_id: "rec1"}, %{record_id: "rec2"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.batch_update",
               %{
                 base_id: "appTest1",
                 table_id: "tblTest1",
                 records: [
                   %{id: "rec1", fields: %{"Name" => "Updated 1"}},
                   %{id: "rec2", fields: %{"Name" => "Updated 2"}}
                 ]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch delete records through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok, %{records: [%{record_id: "rec1"}, %{record_id: "rec2"}]}} =
             Connect.invoke(
               Airtable.integration(),
               "airtable.records.batch_delete",
               %{
                 base_id: "appTest1",
                 table_id: "tblTest1",
                 record_ids: ["rec1", "rec2"]
               },
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :airtable,
        profile: :personal_access_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: @test_scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :airtable,
        profile: :personal_access_token,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{api_key: "token", airtable_client: FakeAirtableClient},
        scopes: @test_scopes
      })

    {context, lease}
  end
end

defmodule FakeAirtableClient do
  @moduledoc false

  alias Jido.Connect.Airtable

  def list_bases(_params, "token") do
    {:ok,
     [
       Airtable.Base.new!(%{base_id: "appTest1", name: "Test Base"})
     ]}
  end

  def get_base(%{base_id: "appTest1"}, "token") do
    {:ok, Airtable.Base.new!(%{base_id: "appTest1", name: "Test Base"})}
  end

  def list_tables(%{base_id: "appTest1"}, "token") do
    {:ok,
     %{
       tables: [Airtable.Table.new!(%{table_id: "tblTest1", name: "Tasks"})]
     }}
  end

  def list_records(_params, "token") do
    {:ok,
     %{
       records: [Airtable.Record.new!(%{record_id: "rec1", fields: %{"Name" => "Test"}})]
     }}
  end

  def get_record(%{record_id: "rec1"}, "token") do
    {:ok, Airtable.Record.new!(%{record_id: "rec1", fields: %{"Name" => "Test"}})}
  end

  def create_record(%{fields: %{"Name" => "New"}}, "token") do
    {:ok, Airtable.Record.new!(%{record_id: "rec2", fields: %{"Name" => "New"}})}
  end

  def update_record(%{record_id: "rec1", fields: %{"Name" => "Updated"}}, "token") do
    {:ok, Airtable.Record.new!(%{record_id: "rec1", fields: %{"Name" => "Updated"}})}
  end

  def delete_record(%{record_id: "rec1"}, "token") do
    {:ok, Airtable.Record.new!(%{record_id: "rec1"})}
  end

  def create_records(%{records: [%{"Name" => "New 1"}, %{"Name" => "New 2"}]}, "token") do
    {:ok,
     [
       Airtable.Record.new!(%{record_id: "rec2", fields: %{"Name" => "New 1"}}),
       Airtable.Record.new!(%{record_id: "rec3", fields: %{"Name" => "New 2"}})
     ]}
  end

  def update_records(
        %{
          records: [
            %{id: "rec1", fields: %{"Name" => "Updated 1"}},
            %{id: "rec2", fields: %{"Name" => "Updated 2"}}
          ]
        },
        "token"
      ) do
    {:ok,
     [
       Airtable.Record.new!(%{record_id: "rec1", fields: %{"Name" => "Updated 1"}}),
       Airtable.Record.new!(%{record_id: "rec2", fields: %{"Name" => "Updated 2"}})
     ]}
  end

  def delete_records(%{record_ids: ["rec1", "rec2"]}, "token") do
    {:ok,
     [
       Airtable.Record.new!(%{record_id: "rec1"}),
       Airtable.Record.new!(%{record_id: "rec2"})
     ]}
  end
end
