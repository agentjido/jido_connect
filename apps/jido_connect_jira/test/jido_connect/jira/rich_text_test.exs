defmodule Jido.Connect.Jira.RichTextTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Jira.Client.{Normalizer, Response}
  alias Jido.Connect.Jira.Webhook

  # An ADF document composed of examples from Atlassian's document format
  # reference, in a `doc` root as on
  # https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/
  @adf %{
    "version" => 1,
    "type" => "doc",
    "content" => [
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/heading/
      %{
        "type" => "heading",
        "attrs" => %{"level" => 1},
        "content" => [%{"type" => "text", "text" => "Heading 1"}]
      },
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/hardBreak/
      %{
        "type" => "paragraph",
        "content" => [
          %{"type" => "text", "text" => "Hello"},
          %{"type" => "hardBreak"},
          %{"type" => "text", "text" => "world"}
        ]
      },
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/bulletList/
      # with the example of
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/orderedList/
      # nested into its listItem.
      %{
        "type" => "bulletList",
        "content" => [
          %{
            "type" => "listItem",
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => "Hello world"}]
              },
              %{
                "type" => "orderedList",
                "attrs" => %{"order" => 3},
                "content" => [
                  %{
                    "type" => "listItem",
                    "content" => [
                      %{
                        "type" => "paragraph",
                        "content" => [%{"type" => "text", "text" => "Hello world"}]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/marks/link/
      %{
        "type" => "paragraph",
        "content" => [
          %{
            "type" => "text",
            "text" => "Hello world",
            "marks" => [
              %{
                "type" => "link",
                "attrs" => %{"href" => "http://atlassian.com", "title" => "Atlassian"}
              }
            ]
          }
        ]
      },
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mention/
      %{
        "type" => "paragraph",
        "content" => [
          %{
            "type" => "mention",
            "attrs" => %{
              "id" => "ABCDE-ABCDE-ABCDE-ABCDE",
              "text" => "@Bradley Ayers",
              "userType" => "APP"
            }
          }
        ]
      },
      # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/mediaSingle/
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
    ]
  }

  @adf_text Enum.join(
              [
                "Heading 1",
                "Hello",
                "world",
                "- Hello world",
                "  3. Hello world",
                "Hello world (http://atlassian.com)",
                "@Bradley Ayers"
              ],
              "\n"
            )

  # https://developer.atlassian.com/cloud/jira/platform/apis/document/nodes/paragraph/
  # as a root, which lacks the `doc` node of the structure page.
  @malformed %{
    "type" => "paragraph",
    "content" => [%{"type" => "text", "text" => "Hello world"}]
  }

  describe "issue descriptions" do
    test "render ADF with the shared projection and list skipped node types" do
      assert {:ok, issue} = Normalizer.issue(with_description(@adf))
      assert issue.description == @adf_text
      assert issue.description_unsupported_nodes == ["mediaSingle"]
    end

    test "pass a plain-string description through" do
      assert {:ok, issue} = Normalizer.issue(with_description("Plain text\n with a break "))
      assert issue.description == "Plain text\n with a break "
      assert issue.description_unsupported_nodes == []
    end

    test "leave both fields empty without a description" do
      payload =
        update_in(fixture!("issue_common.json"), ["fields"], &Map.delete(&1, "description"))

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.description == nil
      assert issue.description_unsupported_nodes == nil
    end

    test "fail explicitly on malformed content" do
      for description <- [@malformed, %{@adf | "content" => %{}}, 42] do
        assert {:error, %Error.ValidationError{reason: :invalid_adf}} =
                 Normalizer.issue(with_description(description))
      end
    end

    test "make issue reads fail without exposing issue content" do
      issue = with_description(@malformed)

      for {handler, body, message} <- [
            {&Response.handle_issue_response/1, issue, "Jira issue response was invalid"},
            {&Response.handle_issue_search_response/1,
             %{"issues" => [fixture!("issue_common.json"), issue]},
             "Jira issue search response was invalid"}
          ] do
        assert {:error, %Error.ProviderError{} = error} =
                 handler.({:ok, %{status: 200, body: body}})

        assert error.message == message
        assert error.reason == :invalid_response
        assert error.delivery == :response_received
        assert error.details == %{field: "description", adf_reason: :invalid_adf}
        refute inspect(error) =~ "Hello world"
        refute inspect(error) =~ "Implement user authentication flow"
      end
    end

    test "render in issue reads and search results" do
      assert {:ok, %{description: @adf_text, description_unsupported_nodes: ["mediaSingle"]}} =
               Response.handle_issue_response({:ok, %{status: 200, body: with_description(@adf)}})

      assert {:ok, %{issues: [%{description_unsupported_nodes: []}, %{description: @adf_text}]}} =
               Response.handle_issue_search_response(
                 {:ok,
                  %{
                    status: 200,
                    body: %{"issues" => [fixture!("issue_common.json"), with_description(@adf)]}
                  }}
               )
    end
  end

  describe "comment bodies" do
    test "render ADF with the shared projection and list skipped node types" do
      assert {:ok, comment} = Normalizer.comment(with_body(@adf))
      assert comment.body == @adf_text
      assert comment.body_unsupported_nodes == ["mediaSingle"]
    end

    test "pass a plain-string body through" do
      assert {:ok, comment} = Normalizer.comment(with_body("Plain body"))
      assert comment.body == "Plain body"
      assert comment.body_unsupported_nodes == []
    end

    test "fail explicitly on malformed content" do
      assert {:error, %Error.ValidationError{reason: :invalid_adf}} =
               Normalizer.comment(with_body(@malformed))
    end
  end

  describe "comment webhook signals" do
    test "a comment_created delivery with an unsupported node yields its text and the skipped types" do
      payload = put_in(fixture!("webhook_comment_created.json"), ["comment", "body"], @adf)

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.change_type == "created"
      assert signal.comment_body == @adf_text
      assert signal.comment_body_unsupported_nodes == ["mediaSingle"]

      body = Jason.encode!(payload)
      headers = %{"x-hub-signature" => sign(body, "webhook-secret")}

      assert {:ok, %WebhookDelivery{normalized_signal: delivered}} =
               Webhook.verify_delivery(body, headers, "webhook-secret", [])

      assert delivered.comment_body == @adf_text
      assert delivered.comment_body_unsupported_nodes == ["mediaSingle"]
    end

    test "a plain-string body of an administrator webhook passes through" do
      payload =
        put_in(
          fixture!("webhook_comment_created.json"),
          ["comment", "body"],
          "First version.\nSecond line"
        )

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.comment_body == "First version.\nSecond line"
      assert signal.comment_body_unsupported_nodes == []
    end

    test "a malformed comment body fails the event explicitly" do
      payload = put_in(fixture!("webhook_comment_updated.json"), ["comment", "body"], @malformed)

      assert {:error, %Error.ProviderError{} = error} = Webhook.normalize_event(payload)
      assert error.reason == :invalid_webhook_event

      assert error.details == %{
               event_type: "comment_updated",
               field: "comment.body",
               adf_reason: :invalid_adf
             }

      body = Jason.encode!(payload)
      headers = %{"x-hub-signature" => sign(body, "webhook-secret")}

      assert {:ok, %WebhookDelivery{event: "comment_updated", normalized_signal: nil}} =
               Webhook.verify_delivery(body, headers, "webhook-secret", [])
    end

    test "jira.comment.changed declares comment_body_unsupported_nodes" do
      trigger =
        Enum.find(Jido.Connect.Jira.integration().triggers, &(&1.id == "jira.comment.changed"))

      assert %{type: {:array, :string}} =
               Enum.find(trigger.signal, &(&1.name == :comment_body_unsupported_nodes))
    end
  end

  defp with_description(description),
    do: put_in(fixture!("issue_common.json"), ["fields", "description"], description)

  defp with_body(body), do: Map.put(fixture!("comment_common.json"), "body", body)

  defp sign(body, secret) do
    "sha256=" <> (:hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower))
  end

  defp fixture!(name) do
    __DIR__
    |> Path.join("../../fixtures/jira/#{name}")
    |> File.read!()
    |> Jason.decode!()
  end
end
