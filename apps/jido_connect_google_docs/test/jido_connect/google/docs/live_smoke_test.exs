defmodule Jido.Connect.Google.Docs.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Docs
  alias Jido.Connect.Google.Docs.Client

  @req_options {:jido_connect_google, :google_req_options}
  # The test account's refresh token holds documents, not documents.readonly,
  # so the connection and the lease declare the scope the token carries.
  @documents_scope "https://www.googleapis.com/auth/documents"

  # The prepared document has the top-level tabs First and Second and the
  # child tab Nested under Second, each holding one seed marker.
  @first_marker "jcl-marker-tab-first"
  @second_marker "jcl-marker-tab-second"
  @nested_marker "jcl-marker-tab-nested"

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"])
  test "reads the scratch document", %{env: env} do
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :google_docs, "document")

    assert {:ok, document} =
             Client.get_document(
               %{document_id: env["GOOGLE_DOCS_SCRATCH_DOCUMENT_ID"]},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert is_map(document)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "reads every tab body of the tabbed document, including the nested tab", %{env: env} do
    LiveSmoke.record(@req_options, :google_docs, "document_with_tabs_content")

    assert {:ok, %{document: document}} =
             get_document(
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], include_tabs_content: true},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert [
             %{tab_id: first_id, title: "First", body: first_body, child_tabs: []},
             %{
               tab_id: second_id,
               title: "Second",
               body: second_body,
               child_tabs: [
                 %{tab_id: nested_id, title: "Nested", body: nested_body, child_tabs: []}
               ]
             }
           ] = document.tabs

    tab_ids = [first_id, second_id, nested_id]
    assert Enum.all?(tab_ids, &(is_binary(&1) and &1 != ""))
    assert Enum.uniq(tab_ids) == tab_ids

    assert text(first_body) =~ @first_marker
    assert text(second_body) =~ @second_marker
    assert text(nested_body) =~ @nested_marker
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "without tab content returns only the first tab in the legacy body", %{env: env} do
    LiveSmoke.record(@req_options, :google_docs, "document_without_tabs_content")

    assert {:ok, %{document: document}} =
             get_document(
               %{document_id: env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"], include_tabs_content: false},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert document.tabs == []
    assert text(document.body) =~ @first_marker
    refute text(document.body) =~ @second_marker
    refute text(document.body) =~ @nested_marker
  end

  defp text(%{"content" => content}) do
    for %{"paragraph" => %{"elements" => elements}} <- content,
        %{"textRun" => %{"content" => run}} <- elements,
        into: "",
        do: run
  end

  defp get_document(input, access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_smoke",
        provider: :google_docs,
        profile: :user,
        tenant_id: "live_smoke",
        owner_type: :app_user,
        owner_id: "live_smoke",
        status: :connected,
        scopes: [@documents_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_smoke",
        actor: %{id: "live_smoke", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live_smoke",
        provider: :google_docs,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: [@documents_scope]
      })

    Connect.invoke(Docs.integration(), "google.docs.document.get", input,
      context: context,
      credential_lease: lease
    )
  end
end
