defmodule Jido.Connect.Jira.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Atlassian Cloud test site.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Jira.{Client, TestRuntime, Webhook}
  alias Jido.Connect.Jira.Client.{Normalizer, Request, Transport}

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_PROJECT_KEY"])
  test "reads the test project", %{env: env} do
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "project")

    assert {:ok, request} = request(env)
    assert {:ok, project} = Client.get_project(env["JIRA_PROJECT_KEY"], request)
    assert is_map(project)
  end

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_ISSUE_KEY"])
  test "renders the test issue's comments and description with the shared ADF projection",
       %{env: env} do
    # One recording for both reads: the sanitizer learns the comment authors
    # from the first response and then replaces their account IDs and names in
    # the description's mention and the `x-aaccountid` header of the second.
    # Avatar URLs carry e-mail hashes and initials, so they become placeholders.
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "issue_rich_text",
      fields: ~w(16x16 24x24 32x32 48x48)
    )

    assert {:ok, request} = request(env)

    # The fourth comment of the test issue holds an image. Comment listing is
    # not a client function yet, so the check reads the first page directly.
    assert {:ok, %{status: 200, body: %{"comments" => comments}}} =
             request
             |> Transport.request()
             |> Req.get(
               url: Request.url(request, "/rest/api/3/issue/#{env["JIRA_ISSUE_KEY"]}/comment"),
               params: %{startAt: 0, maxResults: 4, orderBy: "created"}
             )

    normalized =
      Enum.map(comments, fn comment ->
        assert {:ok, normalized} = Normalizer.comment(comment)
        normalized
      end)

    assert [_ | _] =
             with_image = Enum.filter(normalized, &("mediaSingle" in &1.body_unsupported_nodes))

    assert Enum.all?(normalized -- with_image, &(&1.body_unsupported_nodes == []))

    assert {:ok, %{description: description, description_unsupported_nodes: []}} =
             Client.get_issue(env["JIRA_ISSUE_KEY"], request, fields: ["description"])

    lines = String.split(description, "\n")
    assert length(lines) > 10
    assert Enum.any?(lines, &String.starts_with?(&1, "- "))
    assert Enum.any?(lines, &Regex.match?(~r/^\s*1\. /, &1))
    assert description =~ "@"
  end

  @tag env!(["JIRA_WEBHOOK_SECRET", "JIRA_CAPTURE_DIR"])
  test "the newest captured delivery replays before and after sanitizing", %{env: env} do
    secret = env["JIRA_WEBHOOK_SECRET"]

    capture =
      env["JIRA_CAPTURE_DIR"]
      |> captures()
      |> Enum.max_by(& &1["captured_at"], fn ->
        flunk("no jira-webhook-*.json capture in JIRA_CAPTURE_DIR")
      end)

    event = capture["body"] |> Jason.decode!() |> Map.fetch!("webhookEvent")

    assert {:ok, %{event: ^event}} = LiveSmoke.replay(capture, webhook: Webhook, secret: secret)

    assert {:ok, %{event: ^event}} =
             capture
             |> LiveSmoke.sanitize_capture(secret: secret)
             |> LiveSmoke.replay(webhook: Webhook)
  end

  @tag env!(["JIRA_WEBHOOK_SECRET", "JIRA_CAPTURE_DIR"])
  test "captured comment deliveries pass their plain-string bodies through", %{env: env} do
    deliveries =
      for capture <- captures(env["JIRA_CAPTURE_DIR"]),
          payload <- [Jason.decode!(capture["body"])],
          payload["webhookEvent"] in ["comment_created", "comment_updated"] do
        assert {:ok, delivery} =
                 LiveSmoke.replay(capture, webhook: Webhook, secret: env["JIRA_WEBHOOK_SECRET"])

        body = get_in(payload, ["comment", "body"])
        assert is_binary(body)
        assert delivery.normalized_signal.comment_body == body
        assert delivery.normalized_signal.comment_body_unsupported_nodes == []
        delivery
      end

    assert [_ | _] = deliveries
  end

  defp request(env) do
    [site: env["JIRA_SITE"], email: env["JIRA_EMAIL"], api_token: env["JIRA_API_TOKEN"]]
    |> TestRuntime.build()
    |> Client.request_context()
  end

  defp captures(dir) do
    dir
    |> Path.join("jira-webhook-*.json")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
  end
end
