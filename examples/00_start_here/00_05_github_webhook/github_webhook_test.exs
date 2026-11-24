Code.require_file("github_webhook.ex", __DIR__)
Code.require_file("webhook_host.ex", __DIR__)

defmodule Jido.Connect.Examples.StartHere.GitHubWebhookTest do
  use ExUnit.Case
  @moduletag :integration

  alias Jido.Connect.{Context, Error, Plugin}
  alias Jido.Connect.Examples.StartHere.{GitHubWebhook, Host, WebhookHost}

  @repo "example/widgets"
  @secret "fixture-webhook-secret"

  defmodule Resolver do
    @behaviour Jido.Connect.CredentialResolver

    @impl true
    def resolve_lease(%Context{metadata: %{observer: observer}} = context, action, params) do
      send(observer, {:lease_requested, action, params})
      Host.resolve_lease(context, action, params)
    end
  end

  test "a signed pull request delivery starts a standard Action and requests a lease" do
    {body, headers} = signed_delivery(@repo)

    Host.with_agent(GitHubWebhook, fn server ->
      assert {:ok, %{pull_request: %{number: 42, title: "Update the widgets"}}} =
               WebhookHost.receive_delivery(server, body, headers, @secret, context())

      assert Jido.AgentServer.snapshot(server).agent.state.pull_request.title ==
               "Update the widgets"

      assert_receive {:lease_requested, "github.pull_request.get",
                      %{repo: @repo, pull_number: 42}}

      refute_received {:lease_requested, _, _}
    end)
  end

  test "bad signatures, duplicates, and repositories outside the grant do not request a lease" do
    {body, headers} = signed_delivery(@repo)
    {other_body, other_headers} = signed_delivery("example/other")
    context = context()

    Host.with_agent(GitHubWebhook, fn server ->
      assert {:error, %Error.AuthError{reason: :invalid_signature}} =
               WebhookHost.receive_delivery(server, body, headers, "different-secret", context)

      assert {:error, %Error.ValidationError{reason: :duplicate_delivery}} =
               WebhookHost.receive_delivery(server, body, headers, @secret, context, ["fixture-1"])

      assert {:error, _reason} =
               WebhookHost.receive_delivery(server, other_body, other_headers, @secret, context)

      assert Jido.AgentServer.snapshot(server).agent.state == %{pull_request: %{}}
      refute_received {:lease_requested, _, _}
    end)
  end

  test "the host can look up only the Agent's selected Trigger" do
    trigger_id = "github.webhook.pull_request"

    assert {:ok, %{kind: :webhook, id: ^trigger_id}} =
             Plugin.trigger(GitHubWebhook.definition(), :source, trigger_id)

    assert {:error, %Error.ConfigError{}} =
             Plugin.trigger(GitHubWebhook, :source, "github.pull_request.updated")

    assert {:error, %Error.ConfigError{}} = Plugin.trigger(GitHubWebhook, :other, trigger_id)
  end

  defp context do
    %{integration_context: %Context{} = context, policy: policy} = Host.github(@repo, :fixture)

    %Context{
      context
      | metadata: %{observer: self()},
        policy: policy,
        credential_resolver: Resolver
    }
  end

  defp signed_delivery(repo) do
    body =
      Jason.encode!(%{
        action: "opened",
        repository: %{full_name: repo},
        pull_request: %{number: 42, title: "Webhook title", state: "open"}
      })

    digest = :crypto.mac(:hmac, :sha256, @secret, body) |> Base.encode16(case: :lower)

    {body,
     %{
       "x-github-delivery" => "fixture-1",
       "x-github-event" => "pull_request",
       "x-hub-signature-256" => "sha256=" <> digest
     }}
  end
end
