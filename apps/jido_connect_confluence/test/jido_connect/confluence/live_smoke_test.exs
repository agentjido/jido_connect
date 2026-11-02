defmodule Jido.Connect.Confluence.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Atlassian Cloud test site.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Confluence.{Client, TestRuntime}
  alias Jido.Connect.Confluence.Client.{Request, Transport}
  alias Jido.Connect.Error

  @tag env!(["CONFLUENCE_SITE", "CONFLUENCE_EMAIL", "CONFLUENCE_API_TOKEN", "CONFLUENCE_PAGE_ID"])
  test "reads the plain test page", %{env: env} do
    LiveSmoke.record({:jido_connect_confluence, :confluence_req_options}, :confluence, "page")

    assert {:ok, request} = request(env)
    assert {:ok, page} = Client.get_page(%{id: env["CONFLUENCE_PAGE_ID"]}, request)
    assert is_map(page)
  end

  @tag env!(["CONFLUENCE_SITE", "CONFLUENCE_EMAIL", "CONFLUENCE_API_TOKEN", "CONFLUENCE_PAGE_ID"])
  test "projects the plain page in both modes and keeps its strict text", %{env: env} do
    LiveSmoke.record(
      {:jido_connect_confluence, :confluence_req_options},
      :confluence,
      "plain_page_adf"
    )

    assert {:ok, request} = request(env)
    document = page_adf!(request, env["CONFLUENCE_PAGE_ID"])

    assert {:ok, strict_text} = Jido.Connect.Confluence.ADF.to_text(document)
    assert {:ok, %{text: text, unsupported_nodes: []}} = ADF.project(document)

    assert {:ok, %{text: ^text, unsupported_nodes: []}} =
             ADF.project(document, on_unsupported: :degrade)

    assert text =~ ~r/ \(https:\/\/[^)]+\)/
    refute strict_text =~ ~r/ \(https:\/\/[^)]+\)/
  end

  @tag env!([
         "CONFLUENCE_SITE",
         "CONFLUENCE_EMAIL",
         "CONFLUENCE_API_TOKEN",
         "CONFLUENCE_RICH_PAGE_ID"
       ])
  test "the rich page fails closed in the client and degrades in the projection", %{env: env} do
    page_id = env["CONFLUENCE_RICH_PAGE_ID"]
    assert {:ok, request} = request(env)

    # The page read keeps failing closed on content outside the strict subset.
    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Client.get_page(%{id: page_id}, request)

    LiveSmoke.record(
      {:jido_connect_confluence, :confluence_req_options},
      :confluence,
      "rich_page_adf"
    )

    document = page_adf!(request, page_id)

    assert Jido.Connect.Confluence.ADF.to_text(document) == :error

    assert {:error,
            %Error.ValidationError{
              reason: :unsupported_adf_content,
              details: %{unsupported_nodes: skipped}
            }} = ADF.project(document)

    assert {:ok, %{text: text, unsupported_nodes: ^skipped}} =
             ADF.project(document, on_unsupported: :degrade)

    assert text != ""
    assert Enum.all?(~w(mediaSingle extension annotation), &(&1 in skipped))
  end

  defp request(env) do
    [
      site_url: env["CONFLUENCE_SITE"],
      email: env["CONFLUENCE_EMAIL"],
      api_token: env["CONFLUENCE_API_TOKEN"]
    ]
    |> TestRuntime.build()
    |> Client.request_context()
  end

  # Reads the page's ADF directly: the page action exposes text only, and its
  # degrade input is a separate change.
  defp page_adf!(request, page_id) do
    assert {:ok, %{status: 200, body: body}} =
             request
             |> Transport.request()
             |> Req.get(
               url: Request.url(request, "/api/v2/pages/#{page_id}"),
               params: %{"body-format" => "atlas_doc_format"}
             )

    body |> get_in(["body", "atlas_doc_format", "value"]) |> Jason.decode!()
  end
end
