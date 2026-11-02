defmodule Jido.Connect.Confluence.RecordedADFTest do
  use ExUnit.Case, async: false

  # Replays the page responses that the live tests recorded from the test site
  # (`test/fixtures/confluence/recorded/*_page_adf.json`).

  alias Jido.Connect.Atlassian.ADF
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

  test "the rich page still fails closed through the page read" do
    body = LiveSmoke.fixture!(:confluence, "rich_page_adf")
    Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Client.get_page(%{id: body["id"]}, request())
  end

  test "the rich page degrades to its supported text and the skipped types" do
    document = :confluence |> LiveSmoke.fixture!("rich_page_adf") |> page_adf()

    assert {:error, %Error.ValidationError{reason: :unsupported_adf_content}} =
             ADF.project(document)

    assert ADF.project(document, on_unsupported: :degrade) ==
             {:ok,
              %{
                text:
                  Enum.join(
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
                  ),
                unsupported_nodes: [
                  "extension",
                  "mediaSingle",
                  "bodiedExtension",
                  "date",
                  "annotation"
                ]
              }}
  end

  test "the plain page reads as before and projects with its link target and numbers" do
    body = LiveSmoke.fixture!(:confluence, "plain_page_adf")
    Req.Test.expect(__MODULE__, &Req.Test.json(&1, body))

    assert {:ok, page} = Client.get_page(%{id: body["id"]}, request())
    assert {:ok, page.text} == Jido.Connect.Confluence.ADF.to_text(page_adf(body))

    assert {:ok, %{text: text, unsupported_nodes: []}} = ADF.project(page_adf(body))

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

  defp request do
    assert {:ok, request} = TestRuntime.build() |> Client.request_context()
    request
  end

  defp page_adf(body),
    do: body |> get_in(["body", "atlas_doc_format", "value"]) |> Jason.decode!()
end
