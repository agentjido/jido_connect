defmodule Jido.Connect.Jira.RecordedRichTextTest do
  use ExUnit.Case, async: true

  # Replays the responses that the live test "renders the test issue's
  # comments and description with the shared ADF projection" recorded from the
  # test site (`test/fixtures/jira/recorded/issue_rich_text*.json`).

  alias Jido.Connect.Jira.Client.{Normalizer, Response}
  alias Jido.Connect.TestSupport.LiveSmoke

  test "the recorded issue description keeps lines, lists, the link target and the mention" do
    body = LiveSmoke.fixture!(:jira, "issue_rich_text.2")

    assert {:ok, issue} = Response.handle_issue_response({:ok, %{status: 200, body: body}})
    assert issue.description_unsupported_nodes == []

    assert [
             "Live-test issue",
             "This issue carries the reference data for the Jira live tests. It has bold, " <>
               "italic, inline code and a link (https://example.com/jcl).",
             "Owner for questions: @Person 2.",
             "- First point of the list",
             "- Second point with Umlaute äöü",
             "- Third point",
             "1. Step one",
             "2. Step two",
             ~s{IO.puts("jcl live test")},
             "An info panel inside the description."
             | long_text
           ] = String.split(issue.description, "\n")

    assert length(long_text) == 12
  end

  test "the recorded comment with an image degrades to its text and mediaSingle" do
    %{"comments" => comments} = LiveSmoke.fixture!(:jira, "issue_rich_text")

    normalized =
      Enum.map(comments, fn comment ->
        assert {:ok, normalized} = Normalizer.comment(comment)
        {normalized.id, normalized.body, normalized.body_unsupported_nodes}
      end)

    assert [
             {"42672",
              "First comment with a list and a mention of @Person 2.\n" <>
                "- Comment list item one\n- Comment list item two", []},
             {"42673", "Restricted to the role 'Ext. Mitarbeiter', which the test user has.", []},
             {"42675", "Comment with an embedded image:", ["mediaSingle"]},
             {"42676", long_comment, []}
           ] = normalized

    assert long_comment |> String.split("\n") |> length() == 12
  end
end
