defmodule Jido.Connect.Google.Docs.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Docs

  defmodule FakeDocsClient do
    def get_document(%{document_id: "doc_abc123"}, "token") do
      {:ok,
       Docs.Document.new!(%{
         document_id: "doc_abc123",
         title: "Project Plan",
         revision_id: "rev001"
       })}
    end

    def create_document(%{title: "New Project Plan"}, "token") do
      {:ok,
       Docs.Document.new!(%{
         document_id: "doc_new001",
         title: "New Project Plan",
         revision_id: "rev001"
       })}
    end
  end

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("docs",
        modules: [Docs],
        packs: Docs.catalog_packs(),
        pack: :google_docs_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.docs.document.get" in ids
    refute "google.docs.document.create" in ids
    refute "google.docs.document.batch_update" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.docs.document.get",
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_readonly
             )

    assert descriptor.tool.id == "google.docs.document.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.docs.document.create",
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_readonly
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.docs.document.batch_update",
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_readonly
             )
  end

  test "editor pack allows all tools" do
    results =
      Catalog.search_tools("docs",
        modules: [Docs],
        packs: Docs.catalog_packs(),
        pack: :google_docs_editor
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.docs.document.get" in ids
    assert "google.docs.document.create" in ids
    assert "google.docs.document.batch_update" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.docs.document.create",
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_editor
             )

    assert descriptor.tool.id == "google.docs.document.create"

    assert {:ok, batch_descriptor} =
             Catalog.describe_tool("google.docs.document.batch_update",
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_editor
             )

    assert batch_descriptor.tool.id == "google.docs.document.batch_update"
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              document: %{
                document_id: "doc_abc123",
                title: "Project Plan",
                revision_id: "rev001"
              }
            }} =
             Catalog.call_tool(
               "google.docs.document.get",
               %{document_id: "doc_abc123"},
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_readonly,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.docs.document.create",
               %{title: "New Project Plan"},
               modules: [Docs],
               packs: Docs.catalog_packs(),
               pack: :google_docs_readonly,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/documents.readonly"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google_docs,
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
        provider: :google_docs,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_docs_client: FakeDocsClient},
        scopes: scopes
      })

    {context, lease}
  end
end
