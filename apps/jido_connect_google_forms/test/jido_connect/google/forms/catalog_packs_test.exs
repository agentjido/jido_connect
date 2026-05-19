defmodule Jido.Connect.Google.Forms.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Forms

  defmodule FakeFormsClient do
    def get_form(%{form_id: "1ABCdefGHI"}, "token") do
      {:ok,
       Forms.Form.new!(%{
         form_id: "1ABCdefGHI",
         title: "Customer Survey",
         revision_id: "rev001"
       })}
    end

    def create_form(%{title: "New Survey"}, "token") do
      {:ok,
       Forms.Form.new!(%{
         form_id: "1NEW_form_id",
         title: "New Survey",
         revision_id: "rev001"
       })}
    end

    def list_responses(%{form_id: "1ABCdefGHI"}, "token") do
      {:ok,
       %{
         responses: [
           Forms.Response.new!(%{
             response_id: "ACYDBNhW_resp1",
             form_id: "1ABCdefGHI"
           })
         ]
       }}
    end

    def get_response(%{form_id: "1ABCdefGHI", response_id: "ACYDBNhW_resp1"}, "token") do
      {:ok,
       Forms.Response.new!(%{
         response_id: "ACYDBNhW_resp1",
         form_id: "1ABCdefGHI"
       })}
    end

    def create_watch(%{form_id: "1ABCdefGHI", event_type: "SCHEMA_RESPONSES"}, "token") do
      {:ok,
       Forms.Watch.new!(%{
         watch_id: "watch_abc123",
         target_id: "1ABCdefGHI",
         state: "ACTIVE",
         event_type: "RESPONSE",
         create_time: "2026-05-14T12:00:00.000Z",
         expire_time: "2026-05-21T12:00:00.000Z"
       })}
    end

    def renew_watch(%{form_id: "1ABCdefGHI", watch_id: "watch_abc123"}, "token") do
      {:ok,
       Forms.Watch.new!(%{
         watch_id: "watch_abc123",
         target_id: "1ABCdefGHI",
         state: "ACTIVE",
         event_type: "RESPONSE",
         create_time: "2026-05-14T12:00:00.000Z",
         expire_time: "2026-05-28T12:00:00.000Z"
       })}
    end

    def delete_watch(%{form_id: "1ABCdefGHI", watch_id: "watch_abc123"}, "token") do
      {:ok, %{deleted?: true}}
    end
  end

  # ---------------------------------------------------------------------------
  # Readonly pack
  # ---------------------------------------------------------------------------

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("forms",
        modules: [Forms],
        packs: Forms.catalog_packs(),
        pack: :google_forms_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.forms.form.get" in ids
    assert "google.forms.responses.list" in ids
    assert "google.forms.responses.get" in ids
    assert "google.forms.response.submitted" in ids
    refute "google.forms.form.create" in ids
    refute "google.forms.form.batch_update" in ids
    refute "google.forms.watch.create" in ids
    refute "google.forms.watch.renew" in ids
    refute "google.forms.watch.delete" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.forms.form.get",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert descriptor.tool.id == "google.forms.form.get"

    assert {:ok, responses_descriptor} =
             Catalog.describe_tool("google.forms.responses.list",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert responses_descriptor.tool.id == "google.forms.responses.list"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.forms.form.create",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.forms.form.batch_update",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.forms.watch.create",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert {:ok, trigger_descriptor} =
             Catalog.describe_tool("google.forms.response.submitted",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly
             )

    assert trigger_descriptor.tool.id == "google.forms.response.submitted"
  end

  # ---------------------------------------------------------------------------
  # Responder pack
  # ---------------------------------------------------------------------------

  test "responder pack includes form read, response, and watch tools" do
    results =
      Catalog.search_tools("forms",
        modules: [Forms],
        packs: Forms.catalog_packs(),
        pack: :google_forms_responder
      )

    ids = Enum.map(results, & &1.tool.id)

    # Read tools
    assert "google.forms.form.get" in ids
    assert "google.forms.responses.list" in ids
    assert "google.forms.responses.get" in ids

    # Watch lifecycle tools
    assert "google.forms.watch.create" in ids
    assert "google.forms.watch.renew" in ids
    assert "google.forms.watch.delete" in ids

    # Response-submitted trigger
    assert "google.forms.response.submitted" in ids

    # Excludes form mutation
    refute "google.forms.form.create" in ids
    refute "google.forms.form.batch_update" in ids
  end

  test "responder pack describes response and watch tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.forms.responses.list",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder
             )

    assert descriptor.tool.id == "google.forms.responses.list"

    assert {:ok, watch_descriptor} =
             Catalog.describe_tool("google.forms.watch.create",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder
             )

    assert watch_descriptor.tool.id == "google.forms.watch.create"
  end

  test "responder pack rejects form mutation tools" do
    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.forms.form.create",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.forms.form.batch_update",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder
             )
  end

  # ---------------------------------------------------------------------------
  # Editor pack
  # ---------------------------------------------------------------------------

  test "editor pack allows all tools" do
    results =
      Catalog.search_tools("forms",
        modules: [Forms],
        packs: Forms.catalog_packs(),
        pack: :google_forms_editor
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.forms.form.get" in ids
    assert "google.forms.form.create" in ids
    assert "google.forms.form.batch_update" in ids
    assert "google.forms.responses.list" in ids
    assert "google.forms.responses.get" in ids
    assert "google.forms.watch.create" in ids
    assert "google.forms.watch.renew" in ids
    assert "google.forms.watch.delete" in ids
    assert "google.forms.response.submitted" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.forms.form.create",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_editor
             )

    assert descriptor.tool.id == "google.forms.form.create"

    assert {:ok, batch_descriptor} =
             Catalog.describe_tool("google.forms.form.batch_update",
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_editor
             )

    assert batch_descriptor.tool.id == "google.forms.form.batch_update"
  end

  # ---------------------------------------------------------------------------
  # Pack ordering and delegates
  # ---------------------------------------------------------------------------

  test "catalog_packs returns all packs in ascending privilege order" do
    packs = Forms.catalog_packs()
    pack_ids = Enum.map(packs, & &1.id)

    assert pack_ids == [
             :google_forms_readonly,
             :google_forms_responder,
             :google_forms_editor
           ]

    assert Forms.readonly_pack().id == :google_forms_readonly
    assert Forms.responder_pack().id == :google_forms_responder
    assert Forms.editor_pack().id == :google_forms_editor
  end

  test "each pack declares google_forms provider filter and package metadata" do
    for pack <- Forms.catalog_packs() do
      assert pack.filters == %{provider: :google_forms}
      assert pack.metadata.package == :jido_connect_google_forms
      assert Map.has_key?(pack.metadata, :risk)
    end
  end

  # ---------------------------------------------------------------------------
  # Scope matrix — every pack tool has a matching scope resolver result
  # ---------------------------------------------------------------------------

  test "readonly pack tools resolve to readonly scopes" do
    readonly_scopes = [
      "https://www.googleapis.com/auth/forms.body.readonly",
      "https://www.googleapis.com/auth/forms.responses.readonly"
    ]

    for tool_id <- Forms.readonly_pack().allowed_tools do
      scopes = resolve_scopes(tool_id)

      assert Enum.any?(readonly_scopes, &(&1 in scopes)),
             "readonly pack tool #{tool_id} should resolve to a readonly scope, got: #{inspect(scopes)}"
    end
  end

  test "responder pack tools resolve to readonly or responses-readonly scopes" do
    acceptable = [
      "https://www.googleapis.com/auth/forms.body.readonly",
      "https://www.googleapis.com/auth/forms.responses.readonly"
    ]

    for tool_id <- Forms.responder_pack().allowed_tools do
      scopes = resolve_scopes(tool_id)

      assert Enum.any?(acceptable, &(&1 in scopes)),
             "responder pack tool #{tool_id} should resolve to readonly scope, got: #{inspect(scopes)}"
    end
  end

  test "editor pack mutation tools resolve to write scope" do
    mutation_tools = [
      "google.forms.form.create",
      "google.forms.form.batch_update"
    ]

    for tool_id <- mutation_tools do
      scopes = resolve_scopes(tool_id)

      assert "https://www.googleapis.com/auth/forms.body" in scopes,
             "mutation tool #{tool_id} should require forms.body scope, got: #{inspect(scopes)}"
    end
  end

  # ---------------------------------------------------------------------------
  # call_tool pack enforcement
  # ---------------------------------------------------------------------------

  test "readonly pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              form: %{
                form_id: "1ABCdefGHI",
                title: "Customer Survey",
                revision_id: "rev001"
              }
            }} =
             Catalog.call_tool(
               "google.forms.form.get",
               %{form_id: "1ABCdefGHI"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.forms.form.create",
               %{title: "New Survey"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly,
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{responses: responses}} =
             Catalog.call_tool(
               "google.forms.responses.list",
               %{form_id: "1ABCdefGHI"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_readonly,
               context: context,
               credential_lease: lease
             )

    assert length(responses) == 1
  end

  test "responder pack allows response and watch call_tool" do
    {context, lease} = context_and_lease(scopes: responses_scopes())

    assert {:ok, %{responses: responses}} =
             Catalog.call_tool(
               "google.forms.responses.list",
               %{form_id: "1ABCdefGHI"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder,
               context: context,
               credential_lease: lease
             )

    assert length(responses) == 1

    assert {:ok, %{response: response}} =
             Catalog.call_tool(
               "google.forms.responses.get",
               %{form_id: "1ABCdefGHI", response_id: "ACYDBNhW_resp1"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder,
               context: context,
               credential_lease: lease
             )

    assert response.response_id == "ACYDBNhW_resp1"

    assert {:ok, %{watch: watch}} =
             Catalog.call_tool(
               "google.forms.watch.create",
               %{form_id: "1ABCdefGHI", event_type: "SCHEMA_RESPONSES"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder,
               context: context,
               credential_lease: lease
             )

    assert watch.watch_id == "watch_abc123"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.forms.form.create",
               %{title: "New Survey"},
               modules: [Forms],
               packs: Forms.catalog_packs(),
               pack: :google_forms_responder,
               context: context,
               credential_lease: lease
             )
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp resolve_scopes(tool_id) do
    Jido.Connect.Google.Forms.ScopeResolver.required_scopes(
      %{id: tool_id},
      %{},
      %{scopes: []}
    )
  end

  defp responses_scopes do
    [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/forms.body.readonly",
      "https://www.googleapis.com/auth/forms.responses.readonly"
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/forms.body.readonly",
        "https://www.googleapis.com/auth/forms.responses.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google_forms,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
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
        provider: :google_forms,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_forms_client: FakeFormsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
