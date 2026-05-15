defmodule Jido.Connect.Google.DocsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Docs
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @docs_action_modules [
    Jido.Connect.Google.Docs.Actions.GetDocument,
    Jido.Connect.Google.Docs.Actions.CreateDocument
  ]

  @docs_dsl_fragments [
    Jido.Connect.Google.Docs.Actions.Documents
  ]

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"

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

  test "declares Google Docs provider metadata" do
    spec = Docs.integration()

    assert spec.id == :google_docs
    assert spec.package == :jido_connect_google_docs
    assert spec.name == "Google Docs"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :docs, :documents, :productivity]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.docs.document.get",
             "google.docs.document.create"
           ]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Docs,
      otp_app: :jido_connect_google_docs,
      action_modules: @docs_action_modules,
      plugin_module: Jido.Connect.Google.Docs.Plugin,
      plugin_name: "google_docs"
    )
  end

  test "loads Docs Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@docs_dsl_fragments)
  end

  test "invokes get document through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              document: %{
                document_id: "doc_abc123",
                title: "Project Plan",
                revision_id: "rev001"
              }
            }} =
             Connect.invoke(
               Docs.integration(),
               "google.docs.document.get",
               %{document_id: "doc_abc123"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create document through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              document: %{
                document_id: "doc_new001",
                title: "New Project Plan",
                revision_id: "rev001"
              }
            }} =
             Connect.invoke(
               Docs.integration(),
               "google.docs.document.create",
               %{title: "New Project Plan"},
               context: context,
               credential_lease: lease
             )
  end

  test "fails before handler execution when required Docs scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@readonly_scope]
            }} =
             Connect.invoke(
               Docs.integration(),
               "google.docs.document.get",
               %{document_id: "doc_abc123"},
               context: context,
               credential_lease: lease
             )
  end

  test "write actions require full Docs scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@write_scope]
            }} =
             Connect.invoke(
               Docs.integration(),
               "google.docs.document.create",
               %{title: "New Project Plan"},
               context: context,
               credential_lease: lease
             )
  end

  defp write_scopes do
    [
      "openid",
      "email",
      "profile",
      @write_scope
    ]
  end

  defp context_and_lease(opts \\ []) do
    scopes =
      Keyword.get(opts, :scopes, [
        "openid",
        "email",
        "profile",
        @readonly_scope
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
