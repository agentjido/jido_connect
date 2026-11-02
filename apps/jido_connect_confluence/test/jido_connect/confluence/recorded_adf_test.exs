defmodule Jido.Connect.Confluence.RecordedADFTest do
  use ExUnit.Case, async: false

  # Page text and the unsupported-content policy of `confluence.page.get` on
  # the page responses that the live tests recorded from the test site
  # (`test/fixtures/confluence/recorded/*_page_adf.json`), and on copies of
  # them that change one part for content the test site does not have.

  alias Jido.Connect
  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Confluence
  alias Jido.Connect.Confluence.{Client, TestRuntime}
  alias Jido.Connect.Error
  alias Jido.Connect.TestSupport.LiveSmoke

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

  # The supported text of the recorded rich page. The excerpt macro's body
  # ("An excerpt macro.") is missing because the projection skips a
  # `bodiedExtension` with its content.
  @rich_text Enum.join(
               [
                 "This page carries content outside the supported ADF subset.",
                 "Images",
                 "Macros",
                 "An info macro.",
                 ~s{IO.puts("jcl")},
                 "Date and comment",
                 "Due on .",
                 "The phrase JCL inline anchor carries an inline comment."
               ],
               "\n"
             )

  @rich_skipped ["extension", "mediaSingle", "bodiedExtension", "date", "annotation"]

  test "the rich page fails closed by default and degrades to its text and skipped types" do
    body = LiveSmoke.fixture!(:confluence, "rich_page_adf")

    assert_fails_closed(body)

    assert %{text: @rich_text, unsupported_nodes: @rich_skipped, truncated: false} =
             read(body, %{on_unsupported: "degrade"})

    Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

    assert {:ok, %{text: @rich_text, unsupported_nodes: @rich_skipped}} =
             Connect.invoke(
               Confluence,
               "confluence.page.get",
               %{id: body["id"], on_unsupported: "degrade"},
               TestRuntime.invoke_opts(runtime())
             )
  end

  test "an image caption fails the page by default and is skipped with its image on request" do
    # The images on the test site have no caption. This copy of the recorded
    # rich page gives its first image one, as the ADF JSON schema allows
    # (`mediaSingle_caption_node`, `caption_node` in
    # https://unpkg.com/@atlaskit/adf-schema/dist/json-schema/v1/full.json).
    caption = %{
      "type" => "caption",
      "content" => [%{"type" => "text", "text" => "A caption of the first image."}]
    }

    body =
      :confluence
      |> LiveSmoke.fixture!("rich_page_adf")
      |> update_adf(fn content ->
        index = Enum.find_index(content, &(&1["type"] == "mediaSingle"))

        List.update_at(
          content,
          index,
          &Map.update!(&1, "content", fn nodes -> nodes ++ [caption] end)
        )
      end)

    assert_fails_closed(body)

    # The caption sits inside the skipped `mediaSingle`, so its text is
    # missing and only the outer type is listed.
    assert %{text: @rich_text, unsupported_nodes: @rich_skipped} =
             read(body, %{on_unsupported: "degrade"})
  end

  test "an inline comment alone fails the page by default and keeps its text on request" do
    # No page on the test site has an inline comment as its only unsupported
    # content. This copy of the recorded plain page puts the annotation mark
    # recorded on the rich page on its heading text.
    [annotation] =
      :confluence
      |> LiveSmoke.fixture!("rich_page_adf")
      |> page_adf()
      |> Map.fetch!("content")
      |> Enum.flat_map(&Map.get(&1, "content", []))
      |> Enum.flat_map(&Map.get(&1, "marks", []))
      |> Enum.filter(&(&1["type"] == "annotation"))

    plain = LiveSmoke.fixture!(:confluence, "plain_page_adf")

    body =
      update_adf(plain, fn [heading | rest] ->
        [put_in(heading, ["content", Access.at(0), "marks"], [annotation]) | rest]
      end)

    assert_fails_closed(body)

    plain_text = read(plain, %{on_unsupported: "fail"}).text

    assert %{text: ^plain_text, unsupported_nodes: ["annotation"]} =
             read(body, %{on_unsupported: "degrade"})
  end

  test "the plain page reads alike in both modes, through the shared projection" do
    body = LiveSmoke.fixture!(:confluence, "plain_page_adf")
    page = read(body)

    refute Map.has_key?(page, :unsupported_nodes)
    assert read(body, %{on_unsupported: "fail"}) == page
    assert read(body, %{on_unsupported: "degrade"}) == Map.put(page, :unsupported_nodes, [])

    assert {:ok, %{text: text, unsupported_nodes: []}} = ADF.project(page_adf(body))
    assert page.text == text

    assert [
             "Plain live-test page",
             "This page holds only content the ADF projection supports: headings, " <>
               "paragraphs, bold, italic, code and a link (https://example.com/jcl).",
             "- First list item",
             "- Second list item with Umlaute äöü",
             "1. Step one",
             "2. Step two"
             | long_text
           ] = String.split(text, "\n")

    assert length(long_text) == 12
  end

  test "a page beyond the projection's node limit fails in both modes and names the limit" do
    # The plain page stays below the default limit of 50,000 nodes, so this
    # test lowers the shared configured limit to 10 instead of changing the
    # recording.
    previous = Application.get_env(:jido_connect_atlassian, ADF)
    Application.put_env(:jido_connect_atlassian, ADF, max_nodes: 10)

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_atlassian, ADF, previous)
      else
        Application.delete_env(:jido_connect_atlassian, ADF)
      end
    end)

    body = LiveSmoke.fixture!(:confluence, "plain_page_adf")

    for input <- [%{id: body["id"]}, %{id: body["id"], on_unsupported: "degrade"}] do
      assert_projection_error(body, input, :adf_node_limit_exceeded)
    end
  end

  test "the plain page truncates by characters, not bytes, in both modes" do
    body = LiveSmoke.fixture!(:confluence, "plain_page_adf")

    text =
      "Plain live-test page\n" <>
        "This page holds only content the ADF projection supports: headings, " <>
        "paragraphs, bold, italic, code and a link (https://example.com/jcl).\n" <>
        "- First list item\n" <>
        "- Second list item with Umlaute ä"

    limit = String.length(text)
    assert byte_size(text) > limit

    for input <- [%{max_characters: limit}, %{max_characters: limit, on_unsupported: "degrade"}] do
      assert %{text: ^text, character_count: 1267, truncated: true} = read(body, input)
    end
  end

  # Today's unsupported-content error, without the input and with "fail". Its
  # public map names the projection's reason, so a caller can tell that
  # "degrade" would read the page.
  defp assert_fails_closed(body) do
    for input <- [%{id: body["id"]}, %{id: body["id"], on_unsupported: "fail"}] do
      assert_projection_error(body, input, :unsupported_adf_content)
    end
  end

  defp assert_projection_error(body, input, adf_reason) do
    Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

    assert {:error,
            %Error.ProviderError{
              message: "Confluence page response was invalid",
              provider: :confluence,
              reason: :invalid_response,
              delivery: :response_received,
              mutation?: false,
              details: %{body_summary: %{type: :map}, field: "body", adf_reason: ^adf_reason}
            } = error} = Client.get_page(input, request())

    public_reason = Atom.to_string(adf_reason)

    assert %{
             reason: :invalid_response,
             details: %{"field" => "body", "adf_reason" => ^public_reason}
           } = Error.to_map(error)
  end

  defp read(body, input \\ %{}) do
    Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))
    assert {:ok, page} = Client.get_page(Map.put(input, :id, body["id"]), request())
    page
  end

  defp runtime, do: TestRuntime.build(provider_client: Client)

  defp request do
    assert {:ok, request} = Client.request_context(runtime())
    request
  end

  defp page_adf(body),
    do: body |> get_in(["body", "atlas_doc_format", "value"]) |> Jason.decode!()

  # Changes the top-level content of the page's ADF document, which the
  # recording holds as a JSON string.
  defp update_adf(body, fun) do
    document = page_adf(body)
    value = Jason.encode!(Map.update!(document, "content", fun))
    put_in(body, ["body", "atlas_doc_format", "value"], value)
  end
end
