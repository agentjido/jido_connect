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
  end

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
    refute "google.forms.form.create" in ids
    refute "google.forms.form.batch_update" in ids

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
  end

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

  test "pack restrictions apply to call_tool" do
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
