defmodule Jido.Connect.Atlassian.ADFStrictTextTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Atlassian.ADF

  # ADF fixtures follow Atlassian's document format reference. Each fixture
  # names the page it comes from.

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/
  @heading %{
    "type" => "heading",
    "attrs" => %{"level" => 1},
    "content" => [%{"type" => "text", "text" => "Heading 1"}]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/hardBreak/
  @hard_break_paragraph %{
    "type" => "paragraph",
    "content" => [
      %{"type" => "text", "text" => "Hello"},
      %{"type" => "hardBreak"},
      %{"type" => "text", "text" => "world"}
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/bulletList/
  @bullet_list %{
    "type" => "bulletList",
    "content" => [
      %{
        "type" => "listItem",
        "content" => [
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Hello world"}]}
        ]
      }
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mention/
  @mention %{
    "type" => "mention",
    "attrs" => %{
      "id" => "ABCDE-ABCDE-ABCDE-ABCDE",
      "text" => "@Bradley Ayers",
      "userType" => "APP"
    }
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/link/
  @http_link_text %{
    "type" => "text",
    "text" => "Hello world",
    "marks" => [
      %{"type" => "link", "attrs" => %{"href" => "http://atlassian.com", "title" => "Atlassian"}}
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/date/
  @date %{"type" => "date", "attrs" => %{"timestamp" => "1582152559"}}

  describe "to_text/1" do
    test "renders the supported subset with the strict rendering of the former Confluence module" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
      document =
        doc([
          @heading,
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "text", "text" => "Hello "},
              %{"type" => "text", "text" => "world", "marks" => [%{"type" => "strong"}]}
            ]
          },
          @hard_break_paragraph,
          @bullet_list,
          %{"type" => "paragraph", "content" => [@mention]},
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/rule/
          %{"type" => "rule"},
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/inlineCard/
          %{
            "type" => "paragraph",
            "content" => [
              %{"type" => "inlineCard", "attrs" => %{"url" => "https://atlassian.com"}}
            ]
          },
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/panel/
          %{
            "type" => "panel",
            "attrs" => %{"panelType" => "info"},
            "content" => [%{"type" => "paragraph", "content" => [text("Hello world")]}]
          },
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/codeBlock/
          %{
            "type" => "codeBlock",
            "attrs" => %{"language" => "javascript", "wrap" => true, "hideLineNumbers" => true},
            "content" => [text("var foo = {};\nvar bar = [];")]
          }
        ])

      assert ADF.to_text(document) ==
               {:ok,
                "Heading 1\nHello world\nHello\nworld\n- Hello world\n@Bradley Ayers\n---\nhttps://atlassian.com\nHello world\n\nvar foo = {};\nvar bar = [];"}
    end

    test "keeps failing closed on unsupported nodes, non-HTTPS links and malformed roots" do
      assert ADF.to_text(doc([%{"type" => "paragraph", "content" => [@date]}])) == :error

      assert ADF.to_text(doc([%{"type" => "paragraph", "content" => [@http_link_text]}])) ==
               :error

      no_target = %{
        @http_link_text
        | "marks" => [%{"type" => "link", "attrs" => %{"href" => nil}}]
      }

      assert ADF.to_text(doc([%{"type" => "paragraph", "content" => [no_target]}])) == :error

      # The annotation mark of
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/media/
      annotated = %{
        @http_link_text
        | "marks" => [
            %{
              "type" => "annotation",
              "attrs" => %{
                "id" => "c4cbe18e-9902-4734-bf9b-1426a81ef785",
                "annotationType" => "inlineComment"
              }
            }
          ]
      }

      assert ADF.to_text(doc([%{"type" => "paragraph", "content" => [annotated]}])) == :error

      malformed_marks = %{@http_link_text | "marks" => %{"type" => "strong"}}

      assert ADF.to_text(doc([%{"type" => "paragraph", "content" => [malformed_marks]}])) ==
               :error

      dated_item = %{
        "type" => "listItem",
        "content" => [%{"type" => "paragraph", "content" => [@date]}]
      }

      assert ADF.to_text(doc([%{"type" => "bulletList", "content" => [dated_item]}])) == :error

      assert ADF.to_text(%{"type" => "doc", "content" => []}) == :error
      assert ADF.to_text("not a document") == :error
    end
  end

  describe "from_markdown/2" do
    test "converts bounded Markdown into the ADF v1 subset" do
      assert {:ok, document} =
               ADF.from_markdown("# Runbook\n\n- [Safe](https://example.com/path)")

      assert document == %{
               "version" => 1,
               "type" => "doc",
               "content" => [
                 %{
                   "type" => "heading",
                   "attrs" => %{"level" => 1},
                   "content" => [text("Runbook")]
                 },
                 %{
                   "type" => "bulletList",
                   "content" => [
                     %{
                       "type" => "listItem",
                       "content" => [
                         %{
                           "type" => "paragraph",
                           "content" => [
                             %{
                               "type" => "text",
                               "text" => "Safe",
                               "marks" => [
                                 %{
                                   "type" => "link",
                                   "attrs" => %{"href" => "https://example.com/path"}
                                 }
                               ]
                             }
                           ]
                         }
                       ]
                     }
                   ]
                 }
               ]
             }
    end

    test "round-trips quotes, fenced code, rules and ordered lists and keeps unsafe links as text" do
      markdown = """
      # Runbook

      First line
      second line

      1. One
      2. Two

      > Quoted text

      ```elixir
      :ok
      ```

      ---

      [Unsafe](http://example.com) and [Port](https://example.com:8443/x) and [Safe](https://example.com/path)
      """

      assert {:ok, document} = ADF.from_markdown(markdown)

      assert Enum.map(document["content"], & &1["type"]) ==
               ~w(heading paragraph orderedList blockquote codeBlock rule paragraph)

      assert ADF.to_text(document) ==
               {:ok,
                "Runbook\nFirst line\nsecond line\n- One\n- Two\nQuoted text\n\n:ok\n---\n" <>
                  "[Unsafe](http://example.com) and [Port](https://example.com:8443/x) and Safe"}
    end

    test "rejects Markdown beyond the configured length and non-strings" do
      assert {:ok, _document} = ADF.from_markdown("12345", max_length: 5)
      assert ADF.from_markdown("123456", max_length: 5) == :error
      assert ADF.from_markdown(String.duplicate("a", 100_001)) == :error
      assert ADF.from_markdown(nil) == :error
    end

    test "rejects unknown options and a max_length that is not a positive integer" do
      for opts <- [[max_length: nil], [max_length: "5"], [max_length: 0], [max_nodes: 5]] do
        assert_raise ArgumentError, fn -> ADF.from_markdown("12345", opts) end
      end
    end
  end

  defp doc(content), do: %{"version" => 1, "type" => "doc", "content" => content}
  defp text(value), do: %{"type" => "text", "text" => value}
end
