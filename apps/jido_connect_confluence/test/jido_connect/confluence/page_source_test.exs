defmodule Jido.Connect.Confluence.PageSourceTest do
  use ExUnit.Case, async: false

  # `confluence.page.get` on the page responses that the live tests recorded
  # from the test site (`test/fixtures/confluence/recorded/`): the tenant-bound
  # source URL and the errors of the page read.

  alias Jido.Connect
  alias Jido.Connect.Confluence
  alias Jido.Connect.Confluence.{Client, TestRuntime}
  alias Jido.Connect.Error

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_confluence, :confluence_req_options)

    Application.put_env(
      :jido_connect_confluence,
      :confluence_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_confluence, :confluence_req_options, previous)
      else
        Application.delete_env(:jido_connect_confluence, :confluence_req_options)
      end
    end)
  end

  @plain_id "3754688664"
  @plain_url "https://example.atlassian.net/wiki/spaces/JCL/pages/3754688664/JCL+plain+page"

  test "client and generated action return the tenant URL of the page without a list request" do
    recorded = recording!("plain_page_adf")

    expected = %{
      kind: "confluence_page",
      account: "confluence-account-1",
      id: @plain_id,
      title: "JCL plain page",
      revision_id: "1",
      version: 1,
      space_id: "3754655746",
      url: @plain_url,
      text: plain_text(),
      character_count: String.length(plain_text()),
      truncated: false
    }

    expect_page_read(recorded)
    assert Client.get_page(%{id: @plain_id}, request()) == {:ok, expected}

    expect_page_read(recorded)
    assert invoke(%{id: @plain_id}) == {:ok, expected}
  end

  test "an unusable webui link or a foreign base fails the read and names no other host" do
    # The test site returns only valid links, so each case changes one part of
    # the recorded `_links`. The error names no ADF reason, because the page
    # body is not at fault.
    page = "/spaces/JCL/pages/3754688664/JCL+plain+page"

    changes = [
      &Map.delete(&1, "webui"),
      &Map.put(&1, "webui", "https://attacker.example/wiki" <> page),
      &Map.put(&1, "webui", "//attacker.example/wiki" <> page),
      &Map.put(&1, "webui", page <> "?next=https://attacker.example/wiki"),
      &Map.put(&1, "webui", page <> "#https://attacker.example/wiki"),
      &Map.put(&1, "webui", String.pad_trailing(page <> "/", 4_097, "a")),
      &Map.put(&1, "base", "https://attacker.example/wiki")
    ]

    for change <- changes,
        input <- [%{id: @plain_id}, %{id: @plain_id, on_unsupported: "degrade"}] do
      "plain_page_adf"
      |> recording!()
      |> update_in(["body", "_links"], change)
      |> expect_page_read()

      assert {:error,
              %Error.ProviderError{
                provider: :confluence,
                reason: :invalid_response,
                delivery: :response_received,
                mutation?: false
              } = error} = Client.get_page(input, request())

      refute rendered(error) =~ "attacker.example"
      refute Map.has_key?(error.details, :adf_reason)
    end
  end

  test "an unknown on_unsupported value fails before any request" do
    # No request is expected: a request would find no Req.Test stub.
    for value <- ["skip", "Degrade", "", :degrade, true] do
      assert {:error,
              %Error.ValidationError{
                reason: :invalid_confluence_input,
                subject: :on_unsupported
              }} = Client.get_page(%{id: @plain_id, on_unsupported: value}, request())

      assert {:error, %Error.ValidationError{}} = invoke(%{id: @plain_id, on_unsupported: value})
    end
  end

  test "a denied page returns a normalized error without content in both modes" do
    # Confluence answers 404 for a page the user may not read, as the recorded
    # read of the restricted test page shows, and for a missing page alike.
    recorded = recording!("restricted_page")

    for input <- [%{id: "3754819634"}, %{id: "3754819634", on_unsupported: "degrade"}] do
      expect_page_read(recorded)

      assert {:error,
              %Error.ProviderError{
                provider: :confluence,
                reason: :http_error,
                status: 404,
                delivery: :rejected,
                mutation?: false
              }} = invoke(input)
    end
  end

  test "failed page reads disclose neither credentials nor page text in errors and telemetry" do
    handler = "page-source-telemetry-#{System.unique_integer([:positive])}"
    events = for phase <- [:start, :stop, :exception], do: [:jido, :connect, :invoke, phase]
    :ok = :telemetry.attach_many(handler, events, &__MODULE__.forward_event/4, self())
    on_exit(fn -> :telemetry.detach(handler) end)

    foreign_base =
      put_in(
        recording!("plain_page_adf"),
        ["body", "_links", "base"],
        "https://attacker.example/wiki"
      )

    failures = [
      {recording!("rich_page_adf"), %{id: "3754852456"}},
      {foreign_base, %{id: @plain_id, on_unsupported: "degrade"}},
      {recording!("restricted_page"), %{id: "3754819634"}}
    ]

    # The credentials of `runtime/0`, their Basic header value, and text of
    # the recorded pages.
    markers = [
      "page-source-token",
      "user@example.com",
      Base.encode64("user@example.com:page-source-token"),
      "Plain live-test page",
      "Umlaute",
      "An info macro.",
      "carries an inline comment"
    ]

    for {recorded, input} <- failures do
      expect_page_read(recorded)
      assert {:error, error} = invoke(input)

      telemetry =
        for phase <- [:start, :stop] do
          assert_receive {:telemetry, [:jido, :connect, :invoke, ^phase], measurements, metadata}
          inspect({measurements, metadata})
        end

      disclosure = rendered(error) <> Enum.join(telemetry)
      assert Enum.filter(markers, &String.contains?(disclosure, &1)) == []
    end
  end

  @doc false
  def forward_event(event, measurements, metadata, pid),
    do: send(pid, {:telemetry, event, measurements, metadata})

  # Serves a recorded response with its status for the recorded path.
  defp expect_page_read(%{"status" => status, "body" => body, "request" => request}) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == request["path"]
      assert URI.decode_query(conn.query_string) == %{"body-format" => "atlas_doc_format"}

      conn
      |> Plug.Conn.put_status(status)
      |> Req.Test.json(body)
    end)
  end

  # The whole recording, with status and request path. `LiveSmoke.fixture!/2`
  # returns the body only.
  defp recording!(name) do
    [__DIR__, "..", "..", "fixtures", "confluence", "recorded", name <> ".json"]
    |> Path.join()
    |> File.read!()
    |> Jason.decode!()
  end

  defp runtime, do: TestRuntime.build(provider_client: Client, api_token: "page-source-token")

  defp request do
    assert {:ok, request} = Client.request_context(runtime())
    request
  end

  defp invoke(input),
    do:
      Connect.invoke(Confluence, "confluence.page.get", input, TestRuntime.invoke_opts(runtime()))

  defp rendered(error), do: inspect(error) <> inspect(Error.to_map(error))

  # The text of the recorded plain page in the shared projection.
  defp plain_text do
    long_lines =
      for n <- 1..12 do
        number = n |> Integer.to_string() |> String.pad_leading(2, "0")

        "Line #{number} of the long live-test text for the plain page: " <>
          "Umlaute äöü ß, Euro €, Dash –."
      end

    Enum.join(
      [
        "Plain live-test page",
        "This page holds only content the ADF projection supports: headings, " <>
          "paragraphs, bold, italic, code and a link (https://example.com/jcl).",
        "- First list item",
        "- Second list item with Umlaute äöü",
        "1. Step one",
        "2. Step two"
        | long_lines
      ],
      "\n"
    )
  end
end
