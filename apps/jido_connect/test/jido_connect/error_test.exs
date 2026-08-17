defmodule Jido.Connect.ErrorTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.RuntimeFixtures

  test "builds structured auth errors" do
    error = Error.missing_scopes("conn_1", ["repo"])

    assert %Error.AuthError{} = error
    assert error.class == :auth
    assert error.reason == :missing_scopes
    assert error.connection_id == "conn_1"
    assert error.missing_scopes == ["repo"]
  end

  test "builds each public error type" do
    assert %Error.ValidationError{message: "bad"} = Error.validation("bad")
    assert %Error.AuthError{message: "auth"} = Error.auth("auth")

    assert %Error.ProviderError{message: "provider", provider: :demo} =
             Error.provider("provider", %{provider: :demo})

    assert %Error.ConfigError{message: "config", key: :demo} =
             Error.config("config", %{key: :demo})

    assert %Error.ExecutionError{message: "execution", phase: :run} =
             Error.execution("execution", phase: :run)

    assert %Error.InternalError{message: "internal"} = Error.internal("internal")

    assert %Error.ValidationError{reason: :input, details: %{errors: [:bad], operation: :parse}} =
             Error.zoi(:input, :bad, %{operation: :parse})

    assert %Error.AuthError{reason: :connection_required, details: %{action_id: "demo"}} =
             Error.connection_required(%{action_id: "demo"})
  end

  test "converts unknown values through Splode" do
    assert %{
             type: :unknown_error,
             class: :internal,
             message: "boom",
             details: %{},
             retryable?: false
           } = Error.to_map("boom")
  end

  test "serializes public errors with sanitized details and centralized retryability" do
    error =
      Error.provider("GitHub API request failed",
        provider: :github,
        status: 503,
        details: %{
          access_token: "secret-token",
          body: %{"message" => "temporarily unavailable", "private_key" => "secret-key"}
        }
      )

    assert %{
             type: :provider_error,
             class: :provider,
             message: "GitHub API request failed",
             details: %{
               "access_token" => "[redacted]",
               "body_summary" => %{
                 "type" => "map",
                 "size" => 2,
                 "keys" => ["message", "private_key"]
               }
             },
             retryable?: true
           } = Error.to_map(error)

    refute inspect(Error.to_map(error)) =~ "secret-token"
    refute inspect(Error.to_map(error)) =~ "secret-key"
    refute inspect(error.details) =~ "temporarily unavailable"
  end

  test "blocks blind retries for uncertain non-idempotent mutations" do
    action =
      RuntimeFixtures.spec(%{
        action: %{
          mutation?: true,
          risk: :external_write,
          confirmation: :always,
          provider_idempotency?: false
        }
      }).actions
      |> hd()

    error =
      Error.provider("Provider response was lost",
        provider: :demo,
        reason: :request_error
      )
      |> Error.with_action_context(action)

    assert error.delivery == :sent_outcome_unknown
    assert error.action_risk == :external_write
    refute Error.retryable?(error)
    assert Error.retry_guidance(error) == :do_not_retry

    public = Error.to_map(error)
    assert public.delivery == :sent_outcome_unknown
    assert public.retryable? == false
    assert public.retry_guidance == :do_not_retry
  end

  test "permits an uncertain retry when the action declares provider idempotency" do
    action =
      RuntimeFixtures.spec(%{
        action: %{
          mutation?: true,
          risk: :write,
          confirmation: :always,
          provider_idempotency?: true
        }
      }).actions
      |> hd()

    error =
      Error.provider("Provider response was lost",
        provider: :demo,
        reason: :request_error
      )
      |> Error.with_action_context(action)

    assert Error.retryable?(error)
    assert Error.retry_guidance(error) == :retry_with_idempotency
  end
end
