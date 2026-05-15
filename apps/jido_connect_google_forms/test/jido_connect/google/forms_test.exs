defmodule Jido.Connect.Google.FormsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Forms
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @write_scope "https://www.googleapis.com/auth/forms.body"
  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"

  @forms_action_modules [
    Jido.Connect.Google.Forms.Actions.GetForm,
    Jido.Connect.Google.Forms.Actions.CreateForm,
    Jido.Connect.Google.Forms.Actions.BatchUpdateForm,
    Jido.Connect.Google.Forms.Actions.ListResponses,
    Jido.Connect.Google.Forms.Actions.GetResponse
  ]

  @forms_dsl_fragments [
    Jido.Connect.Google.Forms.Actions.Forms,
    Jido.Connect.Google.Forms.Actions.Responses
  ]

  defmodule FakeFormsClient do
    def get_form(%{form_id: "1ABCdefGHI"}, "token") do
      {:ok,
       Forms.Form.new!(%{
         form_id: "1ABCdefGHI",
         title: "Customer Survey",
         description: "Tell us what you think.",
         revision_id: "rev001"
       })}
    end

    def create_form(%{title: "New Survey"}, "token") do
      {:ok,
       Forms.Form.new!(%{
         form_id: "1NEW_form_id",
         title: "New Survey",
         description: nil,
         revision_id: "rev001"
       })}
    end

    def batch_update(
          %{form_id: "1ABCdefGHI", requests: [%{update_form_title: _}]},
          "token"
        ) do
      {:ok,
       %{
         form_id: "1ABCdefGHI",
         replies: [%{"updateFormTitle" => %{}}, %{"createItem" => %{"itemId" => "new_1"}}]
       }}
    end

    def list_responses(%{form_id: "1ABCdefGHI"}, "token") do
      {:ok,
       %{
         responses: [
           Forms.Response.new!(%{
             response_id: "ACYDBNhW_resp1",
             form_id: "1ABCdefGHI",
             create_time: "2026-05-14T10:00:00.000Z"
           }),
           Forms.Response.new!(%{
             response_id: "ACYDBNhW_resp2",
             form_id: "1ABCdefGHI",
             create_time: "2026-05-14T11:00:00.000Z"
           })
         ],
         next_page_token: "next_page_abc"
       }}
    end

    def get_response(%{form_id: "1ABCdefGHI", response_id: "ACYDBNhW_resp1"}, "token") do
      {:ok,
       Forms.Response.new!(%{
         response_id: "ACYDBNhW_resp1",
         form_id: "1ABCdefGHI",
         respondent_email: "user@example.com",
         create_time: "2026-05-14T10:00:00.000Z",
         last_submitted_time: "2026-05-14T10:02:30.000Z"
       })}
    end
  end

  test "declares Google Forms provider metadata" do
    spec = Forms.integration()

    assert spec.id == :google_forms
    assert spec.package == :jido_connect_google_forms
    assert spec.name == "Google Forms"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :forms, :surveys, :productivity]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.forms.form.get",
             "google.forms.form.create",
             "google.forms.form.batch_update",
             "google.forms.responses.list",
             "google.forms.responses.get"
           ]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Forms,
      id_prefix: "google.forms.",
      pack_id_prefix: "google_forms_",
      module_namespace: Jido.Connect.Google.Forms
    )
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Forms,
      otp_app: :jido_connect_google_forms,
      action_modules: @forms_action_modules,
      plugin_module: Jido.Connect.Google.Forms.Plugin,
      plugin_name: "google_forms"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Forms,
      readonly_pack: :google_forms_readonly,
      editor_pack: :google_forms_editor
    )

    ConnectorContracts.assert_plugin_tool_availability(Forms)
  end

  test "loads Forms Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@forms_dsl_fragments)
  end

  test "invokes get form through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              form: %{
                form_id: "1ABCdefGHI",
                title: "Customer Survey",
                revision_id: "rev001"
              }
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.get",
               %{form_id: "1ABCdefGHI"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create form through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok,
            %{
              form: %{
                form_id: "1NEW_form_id",
                title: "New Survey",
                revision_id: "rev001"
              }
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.create",
               %{title: "New Survey"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes batch update form through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{replies: replies}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.batch_update",
               %{
                 form_id: "1ABCdefGHI",
                 requests: [%{update_form_title: %{title: "Updated Survey"}}]
               },
               context: context,
               credential_lease: lease
             )

    assert length(replies) == 2
  end

  test "fails before handler execution when required Forms scopes are missing" do
    {context, lease} = context_and_lease(scopes: ["openid", "email", "profile"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@readonly_scope]
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.get",
               %{form_id: "1ABCdefGHI"},
               context: context,
               credential_lease: lease
             )
  end

  test "write actions require full Forms scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@write_scope]
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.create",
               %{title: "New Survey"},
               context: context,
               credential_lease: lease
             )
  end

  test "batch update requires full Forms scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@write_scope]
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.batch_update",
               %{form_id: "1ABCdefGHI", requests: [%{update_form_title: %{title: "x"}}]},
               context: context,
               credential_lease: lease
             )
  end

  test "batch update rejects empty requests" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_batch_update_requests}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.batch_update",
               %{form_id: "1ABCdefGHI", requests: []},
               context: context,
               credential_lease: lease
             )
  end

  test "batch update rejects requests with multiple operations per map" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_batch_update_request}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.batch_update",
               %{
                 form_id: "1ABCdefGHI",
                 requests: [%{update_form_title: %{}, create_item: %{}}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "batch update rejects unsupported operations" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :unsupported_batch_update_operation}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.form.batch_update",
               %{
                 form_id: "1ABCdefGHI",
                 requests: [%{dangerous_operation: %{}}]
               },
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list responses through injected client and lease" do
    {context, lease} = context_and_lease(scopes: responses_scopes())

    assert {:ok, %{responses: responses, next_page_token: "next_page_abc"}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.responses.list",
               %{form_id: "1ABCdefGHI"},
               context: context,
               credential_lease: lease
             )

    assert length(responses) == 2

    resp_ids = Enum.map(responses, & &1[:response_id])
    assert "ACYDBNhW_resp1" in resp_ids
    assert "ACYDBNhW_resp2" in resp_ids
    assert Enum.all?(responses, &(&1[:form_id] == "1ABCdefGHI"))
  end

  test "invokes get response through injected client and lease" do
    {context, lease} = context_and_lease(scopes: responses_scopes())

    assert {:ok, %{response: response}} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.responses.get",
               %{form_id: "1ABCdefGHI", response_id: "ACYDBNhW_resp1"},
               context: context,
               credential_lease: lease
             )

    assert response.response_id == "ACYDBNhW_resp1"
    assert response.form_id == "1ABCdefGHI"
    assert response.respondent_email == "user@example.com"
  end

  test "list responses requires responses readonly scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@responses_readonly_scope]
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.responses.list",
               %{form_id: "1ABCdefGHI"},
               context: context,
               credential_lease: lease
             )
  end

  test "get response requires responses readonly scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@responses_readonly_scope]
            }} =
             Connect.invoke(
               Forms.integration(),
               "google.forms.responses.get",
               %{form_id: "1ABCdefGHI", response_id: "ACYDBNhW_resp1"},
               context: context,
               credential_lease: lease
             )
  end

  defp responses_scopes do
    [
      "openid",
      "email",
      "profile",
      @responses_readonly_scope
    ]
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
