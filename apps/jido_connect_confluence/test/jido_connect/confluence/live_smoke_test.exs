defmodule Jido.Connect.Confluence.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Atlassian Cloud test site.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Confluence
  alias Jido.Connect.Confluence.{Client, TestRuntime}
  alias Jido.Connect.Error

  @req_options {:jido_connect_confluence, :confluence_req_options}

  @tag env!(["CONFLUENCE_SITE", "CONFLUENCE_EMAIL", "CONFLUENCE_API_TOKEN", "CONFLUENCE_PAGE_ID"])
  test "reads the plain test page", %{env: env} do
    LiveSmoke.record(@req_options, :confluence, "page")

    assert {:ok, request} = request(env)
    assert {:ok, page} = Client.get_page(%{id: env["CONFLUENCE_PAGE_ID"]}, request)
    assert is_map(page)
  end

  # The page tests below compare each live read with the committed recording
  # of the same page: ID, version, a SHA-256 digest of the text and the
  # unsupported-node outcome. Assertions leave text and URL out of page maps,
  # and a read expected to fail never prints the page it returned, so a
  # failure prints neither page content nor the tenant host. Only the default
  # read is recorded; the degrade read before it receives the same response.

  @tag env!(["CONFLUENCE_SITE", "CONFLUENCE_EMAIL", "CONFLUENCE_API_TOKEN", "CONFLUENCE_PAGE_ID"])
  test "confluence.page.get reads the plain page alike in both modes", %{env: env} do
    page_id = env["CONFLUENCE_PAGE_ID"]

    assert {:ok, degraded} = get_page(env, %{id: page_id, on_unsupported: "degrade"})

    LiveSmoke.record(@req_options, :confluence, "plain_page_adf")
    assert {:ok, page} = get_page(env, %{id: page_id})

    recorded = LiveSmoke.fixture!(:confluence, "plain_page_adf")
    expected = recorded_projection(recorded)
    version = recorded["version"]["number"]

    assert expected.unsupported_nodes == []
    assert %{id: ^page_id, version: ^version, truncated: false} = fields(page)
    refute Map.has_key?(page, :unsupported_nodes)
    assert digest(page.text) == digest(expected.text)
    assert page.character_count == String.length(expected.text)

    assert Map.delete(fields(degraded), :unsupported_nodes) == fields(page)
    same_url? = degraded.url == page.url
    assert same_url?
    assert digest(degraded.text) == digest(page.text)
    assert degraded.unsupported_nodes == []

    assert_tenant_url(page.url, env, recorded)
  end

  @tag env!([
         "CONFLUENCE_SITE",
         "CONFLUENCE_EMAIL",
         "CONFLUENCE_API_TOKEN",
         "CONFLUENCE_RICH_PAGE_ID"
       ])
  test "confluence.page.get fails closed on the rich page and degrades on request",
       %{env: env} do
    page_id = env["CONFLUENCE_RICH_PAGE_ID"]

    assert {:ok, degraded} = get_page(env, %{id: page_id, on_unsupported: "degrade"})

    LiveSmoke.record(@req_options, :confluence, "rich_page_adf")

    error = read_error!(env, %{id: page_id})

    assert %Error.ProviderError{
             provider: :confluence,
             reason: :invalid_response,
             delivery: :response_received,
             mutation?: false,
             details: %{field: "body", adf_reason: :unsupported_adf_content}
           } = error

    recorded = LiveSmoke.fixture!(:confluence, "rich_page_adf")
    expected = recorded_projection(recorded)
    version = recorded["version"]["number"]

    assert %{id: ^page_id, version: ^version, truncated: false} = fields(degraded)
    assert digest(degraded.text) == digest(expected.text)
    assert degraded.unsupported_nodes == expected.unsupported_nodes
    assert Enum.all?(~w(mediaSingle extension annotation), &(&1 in degraded.unsupported_nodes))

    assert_tenant_url(degraded.url, env, recorded)
    assert disclosures(error, env, degraded.text) == 0
  end

  @tag env!([
         "CONFLUENCE_SITE",
         "CONFLUENCE_EMAIL",
         "CONFLUENCE_API_TOKEN",
         "CONFLUENCE_RESTRICTED_PAGE_ID"
       ])
  test "confluence.page.get returns a normalized error for the unreadable page in both modes",
       %{env: env} do
    page_id = env["CONFLUENCE_RESTRICTED_PAGE_ID"]

    degraded = read_error!(env, %{id: page_id, on_unsupported: "degrade"})

    LiveSmoke.record(@req_options, :confluence, "restricted_page")
    error = read_error!(env, %{id: page_id})

    # Confluence answers 404 for a page the user may not read, as for a
    # missing one.
    for failure <- [error, degraded] do
      assert %Error.ProviderError{
               provider: :confluence,
               reason: :http_error,
               status: 404,
               delivery: :rejected,
               mutation?: false
             } = failure

      assert disclosures(failure, env, "") == 0
    end
  end

  defp request(env), do: env |> runtime() |> Client.request_context()

  defp runtime(env) do
    TestRuntime.build(
      site_url: env["CONFLUENCE_SITE"],
      email: env["CONFLUENCE_EMAIL"],
      api_token: env["CONFLUENCE_API_TOKEN"],
      provider_client: Client
    )
  end

  defp get_page(env, input) do
    opts = env |> runtime() |> TestRuntime.invoke_opts()
    Connect.invoke(Confluence, "confluence.page.get", input, opts)
  end

  # The error of a read expected to fail. A page returned instead fails the
  # test without being printed.
  defp read_error!(env, input) do
    case get_page(env, input) do
      {:error, error} -> error
      {:ok, _page} -> flunk("confluence.page.get returned a page where an error was expected")
    end
  end

  # A page map without the text and the URL with the tenant host.
  defp fields(page), do: Map.drop(page, [:text, :url])

  # The projection of the recorded page in degrade mode: the text and the
  # skipped types the live page should still produce.
  defp recorded_projection(recorded) do
    document = recorded |> get_in(["body", "atlas_doc_format", "value"]) |> Jason.decode!()
    assert {:ok, projection} = ADF.project(document, on_unsupported: :degrade)
    projection
  end

  # The URL points at the tenant site; its path is the recorded `webui` under
  # the `/wiki` root. The comparison stays boolean so a failure prints no host.
  defp assert_tenant_url(url, env, recorded) do
    uri = URI.parse(url)
    tenant_host? = uri.host == URI.parse(env["CONFLUENCE_SITE"]).host

    assert tenant_host?
    assert uri.scheme == "https"
    assert uri.path == "/wiki" <> recorded["_links"]["webui"]
  end

  # Counts the credentials and the page text lines longer than 12 characters
  # that an error renders. A count keeps the values out of failure output.
  defp disclosures(error, env, text) do
    rendered = inspect(error) <> inspect(Error.to_map(error))
    lines = text |> String.split("\n") |> Enum.filter(&(String.length(&1) > 12))

    Enum.count(
      [env["CONFLUENCE_EMAIL"], env["CONFLUENCE_API_TOKEN"] | lines],
      &String.contains?(rendered, &1)
    )
  end

  defp digest(text), do: :sha256 |> :crypto.hash(text) |> Base.encode16(case: :lower)
end
