defmodule Jido.Connect.Atlassian.ADFProjectionTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Error

  # ADF fixtures come from Atlassian's document format reference. Each node
  # cites the page whose example it uses; composed documents put those
  # examples into the `doc` root from the structure page.
  #
  # Structure: https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
  # Nodes:     https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/

  @modes [:fail, :degrade]

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
  @empty_document %{"version" => 1, "type" => "doc", "content" => []}

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/
  @heading %{
    "type" => "heading",
    "attrs" => %{"level" => 1},
    "content" => [%{"type" => "text", "text" => "Heading 1"}]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/paragraph/
  @paragraph %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Hello world"}]}

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/hardBreak/
  @hard_break_paragraph %{
    "type" => "paragraph",
    "content" => [
      %{"type" => "text", "text" => "Hello"},
      %{"type" => "hardBreak"},
      %{"type" => "text", "text" => "world"}
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/orderedList/
  @ordered_list %{
    "type" => "orderedList",
    "attrs" => %{"order" => 3},
    "content" => [
      %{
        "type" => "listItem",
        "content" => [
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Hello world"}]}
        ]
      }
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/bulletList/
  # with the orderedList example above nested into its listItem
  # (https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/listItem/).
  @nested_list %{
    "type" => "bulletList",
    "content" => [
      %{
        "type" => "listItem",
        "content" => [
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Hello world"}]},
          @ordered_list
        ]
      }
    ]
  }

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/link/
  @link_text %{
    "type" => "text",
    "text" => "Hello world",
    "marks" => [
      %{"type" => "link", "attrs" => %{"href" => "http://atlassian.com", "title" => "Atlassian"}}
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

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/date/
  @date %{"type" => "date", "attrs" => %{"timestamp" => "1582152559"}}

  # The Jira reference has no node page for `extension`. The structure page
  # links the ADF JSON schema (http://go.atlassian.com/adf-json-schema), whose
  # `definitions.extension_node` requires `attrs.extensionType` and
  # `attrs.extensionKey`; the values name Confluence's table-of-contents macro.
  @extension %{
    "type" => "extension",
    "attrs" => %{
      "extensionType" => "com.atlassian.confluence.macro.core",
      "extensionKey" => "toc"
    }
  }

  # The Jira reference has no node pages for task and decision lists. These
  # fixtures follow `definitions.taskList_node`, `taskItem_node`,
  # `decisionList_node` and `decisionItem_node` of the ADF JSON schema linked
  # from the structure page (http://go.atlassian.com/adf-json-schema). A
  # taskList holds taskItem and taskList nodes, so a nested task list is a
  # direct child of the outer list; a decisionList holds decisionItem nodes.
  @task_list %{
    "type" => "taskList",
    "attrs" => %{"localId" => "4f9b6d1e-6c5a-4a8e-9f3b-2d7c1e0a5b61"},
    "content" => [
      %{
        "type" => "taskItem",
        "attrs" => %{"localId" => "4f9b6d1e-6c5a-4a8e-9f3b-2d7c1e0a5b62", "state" => "DONE"},
        "content" => [%{"type" => "text", "text" => "Parent task"}]
      },
      %{
        "type" => "taskList",
        "attrs" => %{"localId" => "4f9b6d1e-6c5a-4a8e-9f3b-2d7c1e0a5b63"},
        "content" => [
          %{
            "type" => "taskItem",
            "attrs" => %{"localId" => "4f9b6d1e-6c5a-4a8e-9f3b-2d7c1e0a5b64", "state" => "TODO"},
            "content" => [%{"type" => "text", "text" => "Child task"}]
          }
        ]
      },
      %{
        "type" => "taskItem",
        "attrs" => %{"localId" => "4f9b6d1e-6c5a-4a8e-9f3b-2d7c1e0a5b65", "state" => "TODO"},
        "content" => [%{"type" => "text", "text" => "Next task"}]
      }
    ]
  }

  @decision_list %{
    "type" => "decisionList",
    "attrs" => %{"localId" => "8a2e4c7d-1b3f-4d5e-a6c7-9e0f1a2b3c41"},
    "content" => [
      %{
        "type" => "decisionItem",
        "attrs" => %{"localId" => "8a2e4c7d-1b3f-4d5e-a6c7-9e0f1a2b3c42", "state" => "DECIDED"},
        "content" => [%{"type" => "text", "text" => "Ship on Friday"}]
      }
    ]
  }

  describe "project/2 rendering" do
    test "renders an empty document as empty text in both modes" do
      for mode <- @modes do
        assert ADF.project(@empty_document, on_unsupported: mode) ==
                 {:ok, %{text: "", unsupported_nodes: []}}
      end
    end

    test "keeps document order and line boundaries, link targets and mention text in both modes" do
      document =
        doc([
          @heading,
          @paragraph,
          @hard_break_paragraph,
          @nested_list,
          %{"type" => "paragraph", "content" => [@link_text]},
          %{"type" => "paragraph", "content" => [@mention]}
        ])

      expected =
        Enum.join(
          [
            "Heading 1",
            "Hello world",
            "Hello",
            "world",
            "- Hello world",
            "  3. Hello world",
            "Hello world (http://atlassian.com)",
            "@Bradley Ayers"
          ],
          "\n"
        )

      for mode <- @modes do
        assert ADF.project(document, on_unsupported: mode) ==
                 {:ok, %{text: expected, unsupported_nodes: []}}
      end
    end

    test "fails closed by default" do
      assert ADF.project(@empty_document) == {:ok, %{text: "", unsupported_nodes: []}}
      assert {:error, %Error.ValidationError{}} = ADF.project(doc([media_single()]))
    end

    test "renders the other supported block and inline nodes without listing them" do
      document =
        doc([
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/panel/
          %{"type" => "panel", "attrs" => %{"panelType" => "info"}, "content" => [@paragraph]},
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/blockquote/
          %{"type" => "blockquote", "content" => [@paragraph]},
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/codeBlock/
          %{
            "type" => "codeBlock",
            "attrs" => %{"language" => "javascript", "wrap" => true, "hideLineNumbers" => true},
            "content" => [%{"type" => "text", "text" => "var foo = {};\nvar bar = [];"}]
          },
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/rule/
          %{"type" => "rule"},
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/emoji/
          paragraph([
            %{"type" => "emoji", "attrs" => %{"shortName" => ":grinning:", "text" => "😀"}}
          ]),
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/status/
          paragraph([
            %{
              "type" => "status",
              "attrs" => %{
                "localId" => "abcdef12-abcd-abcd-abcd-abcdef123456",
                "text" => "In Progress",
                "color" => "yellow"
              }
            }
          ]),
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/inlineCard/
          paragraph([%{"type" => "inlineCard", "attrs" => %{"url" => "https://atlassian.com"}}]),
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/table/
          %{
            "type" => "table",
            "attrs" => %{
              "isNumberColumnEnabled" => false,
              "layout" => "center",
              "width" => 900,
              "displayMode" => "default"
            },
            "content" => [
              %{
                "type" => "tableRow",
                "content" => [
                  %{
                    "type" => "tableCell",
                    "attrs" => %{},
                    "content" => [
                      paragraph([%{"type" => "text", "text" => " Row one, cell one"}])
                    ]
                  },
                  %{
                    "type" => "tableCell",
                    "attrs" => %{},
                    "content" => [paragraph([%{"type" => "text", "text" => "Row one, cell two"}])]
                  }
                ]
              }
            ]
          },
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/expand/
          %{"type" => "expand", "attrs" => %{"title" => "Hello world"}, "content" => [@paragraph]}
        ])

      expected =
        Enum.join(
          [
            "Hello world",
            "Hello world",
            "var foo = {};",
            "var bar = [];",
            "---",
            "😀",
            "In Progress",
            "https://atlassian.com",
            " Row one, cell one",
            "Row one, cell two",
            "Hello world"
          ],
          "\n"
        )

      for mode <- @modes do
        assert ADF.project(document, on_unsupported: mode) ==
                 {:ok, %{text: expected, unsupported_nodes: []}}
      end
    end

    test "renders text under formatting marks as plain text" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
      document =
        doc([
          paragraph([
            %{"type" => "text", "text" => "Hello "},
            %{"type" => "text", "text" => "world", "marks" => [%{"type" => "strong"}]}
          ])
        ])

      for mode <- @modes do
        assert ADF.project(document, on_unsupported: mode) ==
                 {:ok, %{text: "Hello world", unsupported_nodes: []}}
      end
    end

    test "renders list items outside lists, list children that are not items and empty lines" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/listItem/
      # placed at the top level, inside the bulletList example
      # (https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/bulletList/)
      # with empty paragraphs around it, and the paragraph example directly in
      # a bulletList.
      empty_paragraph = paragraph([])
      [item] = @nested_list["content"]

      document =
        doc([
          %{"type" => "listItem", "content" => [@paragraph]},
          %{
            "type" => "bulletList",
            "content" => [
              %{"type" => "listItem", "content" => [empty_paragraph, @paragraph]},
              %{"type" => "listItem", "content" => [@paragraph, empty_paragraph, @paragraph]},
              %{item | "content" => []},
              @paragraph
            ]
          }
        ])

      assert ADF.project(document) ==
               {:ok,
                %{
                  text:
                    Enum.join(
                      [
                        "- Hello world",
                        "-",
                        "  Hello world",
                        "- Hello world",
                        "",
                        "  Hello world",
                        "-",
                        "Hello world"
                      ],
                      "\n"
                    ),
                  unsupported_nodes: []
                }}
    end

    test "indents a nested task list under the task before it and renders decisions as items" do
      expected = "- Parent task\n  - Child task\n- Next task\n- Ship on Friday"

      for mode <- @modes do
        assert ADF.project(doc([@task_list, @decision_list]), on_unsupported: mode) ==
                 {:ok, %{text: expected, unsupported_nodes: []}}
      end
    end

    test "treats null text marks as no marks, as the strict rendering does" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/text/
      # with an explicit null `marks`.
      document = doc([paragraph([%{"type" => "text", "text" => "Hello world", "marks" => nil}])])

      assert {:ok, "Hello world"} = ADF.to_text(document)

      for mode <- @modes do
        assert ADF.project(document, on_unsupported: mode) ==
                 {:ok, %{text: "Hello world", unsupported_nodes: []}}
      end
    end

    test "renders an emoji by its short name when it has no text" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/emoji/
      # without the optional `attrs.text`.
      emoji = %{
        "type" => "emoji",
        "attrs" => %{"shortName" => ":awthanks:", "id" => "atlassian-awthanks"}
      }

      assert ADF.project(doc([paragraph([emoji])])) ==
               {:ok, %{text: ":awthanks:", unsupported_nodes: []}}
    end

    test "numbers ordered list items from the order attribute or from one" do
      # The orderedList example with a second item, and once without the
      # optional `attrs.order`, which the ADF JSON schema linked from the
      # structure page marks optional.
      [item] = @ordered_list["content"]
      two_items = %{@ordered_list | "content" => [item, item]}
      unnumbered = Map.delete(@ordered_list, "attrs")

      assert {:ok, %{text: "3. Hello world\n4. Hello world"}} = ADF.project(doc([two_items]))
      assert {:ok, %{text: "1. Hello world"}} = ADF.project(doc([unnumbered]))
    end

    test "renders a link target once for adjacent linked text and once when it equals the text" do
      # The link mark example twice in a row, and with its text set to its target.
      url_text = %{@link_text | "text" => "http://atlassian.com"}

      assert {:ok, %{text: "Hello worldHello world (http://atlassian.com)"}} =
               ADF.project(doc([paragraph([@link_text, @link_text])]))

      assert {:ok, %{text: "http://atlassian.com"}} = ADF.project(doc([paragraph([url_text])]))
    end
  end

  describe "project/2 with unsupported content" do
    test "fails under :fail and degrades under :degrade for mediaSingle, extension and annotation" do
      document =
        doc([
          @paragraph,
          media_single(),
          @extension,
          paragraph([annotated_text()])
        ])

      assert {:error,
              %Error.ValidationError{
                reason: :unsupported_adf_content,
                subject: :adf,
                details: %{unsupported_nodes: ["mediaSingle", "extension", "annotation"]}
              }} = ADF.project(document, on_unsupported: :fail)

      assert ADF.project(document, on_unsupported: :degrade) ==
               {:ok,
                %{
                  text: "Hello world\nHello world",
                  unsupported_nodes: ["mediaSingle", "extension", "annotation"]
                }}
    end

    test "lists each skipped type once in document order and skips nested nodes with their parent" do
      document =
        doc([
          paragraph([@date]),
          media_single(),
          @paragraph,
          paragraph([@date]),
          # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mediaGroup/
          %{
            "type" => "mediaGroup",
            "content" => [
              %{
                "type" => "media",
                "attrs" => %{
                  "type" => "file",
                  "id" => "6e7c7f2c-dd7a-499c-bceb-6f32bfbf30b5",
                  "collection" => "ae730abd-a389-46a7-90eb-c03e75a45bf6"
                }
              }
            ]
          }
        ])

      assert ADF.project(document, on_unsupported: :degrade) ==
               {:ok,
                %{text: "Hello world", unsupported_nodes: ["date", "mediaSingle", "mediaGroup"]}}
    end

    test "treats a mention without display text and a link without target as unsupported" do
      # The ADF JSON schema linked from the structure page makes the mention's
      # `attrs.text` optional; the link example here lacks its required `href`.
      silent_mention = %{@mention | "attrs" => Map.delete(@mention["attrs"], "text")}
      bare_link = %{@link_text | "marks" => [%{"type" => "link", "attrs" => %{}}]}

      assert ADF.project(doc([paragraph([silent_mention]), paragraph([bare_link])]),
               on_unsupported: :degrade
             ) == {:ok, %{text: "Hello world", unsupported_nodes: ["mention", "link"]}}
    end
  end

  describe "project/2 with malformed documents" do
    test "rejects a missing doc root in both modes" do
      for document <- [
            @paragraph,
            Map.delete(@empty_document, "version"),
            "Hello world",
            nil
          ],
          mode <- @modes do
        assert_malformed(ADF.project(document, on_unsupported: mode), :doc_root)
      end
    end

    test "rejects non-list content in both modes" do
      for document <- [
            %{@empty_document | "content" => @paragraph},
            doc([%{@paragraph | "content" => %{"type" => "text", "text" => "Hello world"}}]),
            doc([%{media_single() | "content" => "Hello world"}])
          ],
          mode <- @modes do
        assert_malformed(ADF.project(document, on_unsupported: mode), :content)
      end
    end

    test "rejects a text node without string text in both modes" do
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/text/
      for text_node <- [%{"type" => "text"}, %{"type" => "text", "text" => ["Hello world"]}],
          mode <- @modes do
        assert_malformed(ADF.project(doc([paragraph([text_node])]), on_unsupported: mode), :text)
      end
    end

    test "rejects nodes and marks without a type name in both modes" do
      for {document, problem} <- [
            {doc(["Hello world"]), :node},
            {doc([%{"content" => []}]), :node_type},
            {doc([%{"type" => "Hello world"}]), :node_type},
            {doc([paragraph([%{@link_text | "marks" => %{"type" => "strong"}}])]), :marks},
            {doc([paragraph([%{@link_text | "marks" => false}])]), :marks},
            {doc([paragraph([%{@link_text | "marks" => [%{"attrs" => %{}}]}])]), :marks}
          ],
          mode <- @modes do
        assert_malformed(ADF.project(document, on_unsupported: mode), problem)
      end
    end
  end

  describe "project/2 limits" do
    test "accepts the default nesting depth and rejects one level more in both modes" do
      for mode <- @modes do
        assert {:ok, %{text: _text}} = ADF.project(doc([nested_lists(31)]), on_unsupported: mode)

        assert {:error, %Error.ValidationError{reason: :adf_depth_limit_exceeded} = error} =
                 ADF.project(doc([nested_lists(32)]), on_unsupported: mode)

        assert error.details == %{max_depth: 64}
      end
    end

    test "accepts the default node count and rejects one node more in both modes" do
      # The doc root and one paragraph count as two nodes.
      text = %{"type" => "text", "text" => "Hello world"}

      for mode <- @modes do
        assert {:ok, %{unsupported_nodes: []}} =
                 ADF.project(doc([paragraph(List.duplicate(text, 49_998))]), on_unsupported: mode)

        assert {:error, %Error.ValidationError{reason: :adf_node_limit_exceeded} = error} =
                 ADF.project(doc([paragraph(List.duplicate(text, 49_999))]), on_unsupported: mode)

        assert error.details == %{max_nodes: 50_000}
      end
    end

    test "takes limits per call and counts nodes inside skipped content" do
      assert {:ok, _projection} = ADF.project(doc([@paragraph]), max_depth: 2, max_nodes: 3)

      assert {:error, %Error.ValidationError{reason: :adf_depth_limit_exceeded}} =
               ADF.project(doc([@paragraph]), max_depth: 1)

      assert {:error, %Error.ValidationError{reason: :adf_node_limit_exceeded}} =
               ADF.project(doc([@paragraph]), max_nodes: 2)

      assert {:error, %Error.ValidationError{reason: :adf_node_limit_exceeded}} =
               ADF.project(doc([media_single()]), on_unsupported: :degrade, max_nodes: 2)

      assert {:error, %Error.ValidationError{reason: :adf_depth_limit_exceeded}} =
               ADF.project(doc([media_single()]), on_unsupported: :degrade, max_depth: 1)
    end

    test "rejects unknown options and invalid values" do
      for opts <- [
            [on_unsupported: :ignore],
            [max_depth: 0],
            [max_nodes: "many"],
            [max_length: 10]
          ] do
        assert_raise ArgumentError, fn -> ADF.project(@empty_document, opts) end
      end
    end
  end

  defp assert_malformed(result, problem) do
    assert {:error,
            %Error.ValidationError{
              reason: :invalid_adf,
              subject: :adf,
              details: %{problem: ^problem}
            }} =
             result
  end

  defp nested_lists(0), do: @paragraph

  defp nested_lists(levels) do
    %{
      "type" => "bulletList",
      "content" => [%{"type" => "listItem", "content" => [nested_lists(levels - 1)]}]
    }
  end

  defp paragraph(content), do: %{"type" => "paragraph", "content" => content}

  defp doc(content), do: %{"version" => 1, "type" => "doc", "content" => content}

  # The paragraph example (.../nodes/paragraph/) with the annotation mark from
  # the media example at
  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/media/
  defp annotated_text do
    %{
      "type" => "text",
      "text" => "Hello world",
      "marks" => [
        %{
          "type" => "annotation",
          "attrs" => %{
            "id" => "c4cbe18e-9902-4734-bf9b-1426a81ef785",
            "annotationType" => "inlineComment"
          }
        }
      ]
    }
  end

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mediaSingle/
  defp media_single do
    %{
      "type" => "mediaSingle",
      "attrs" => %{"layout" => "center"},
      "content" => [
        %{
          "type" => "media",
          "attrs" => %{
            "id" => "4478e39c-cf9b-41d1-ba92-68589487cd75",
            "type" => "file",
            "collection" => "MediaServicesSample",
            "alt" => "moon.jpeg",
            "width" => 225,
            "height" => 225
          }
        }
      ]
    }
  end
end
