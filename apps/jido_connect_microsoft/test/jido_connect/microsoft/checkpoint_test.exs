defmodule Jido.Connect.Microsoft.CheckpointTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Microsoft.Checkpoint

  test "builds normalized expired checkpoint errors with reset guidance" do
    provider_error =
      Error.provider("Microsoft Graph API request failed",
        provider: :microsoft,
        reason: :http_error,
        status: 410,
        details: %{message: "Delta token is no longer valid"}
      )

    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: :checkpoint_expired,
              status: 410,
              details: %{
                checkpoint: "delta-1",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                },
                provider_reason: :http_error,
                provider_details: %{message: "Delta token is no longer valid"}
              }
            }} = Checkpoint.expired("Microsoft Graph delta token", "delta-1", provider_error)
  end

  test "builds normalized invalid checkpoint response errors with reset guidance" do
    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: :invalid_response,
              details: %{
                next_link: "loop",
                checkpoint_reset: %{
                  action: :clear_checkpoint,
                  behavior: :initialize_without_replay
                }
              }
            }} =
             Checkpoint.invalid_response("Microsoft Graph response repeated nextLink", %{
               next_link: "loop"
             })
  end

  test "detects provider errors that require checkpoint reset" do
    assert Checkpoint.expired_provider_error?(
             Error.provider("Gone", provider: :microsoft, reason: :http_error, status: 410)
           )

    assert Checkpoint.expired_provider_error?(
             Error.provider("Missing", provider: :microsoft, reason: :http_error, status: 404)
           )

    refute Checkpoint.expired_provider_error?(
             Error.provider("Rate limited",
               provider: :microsoft,
               reason: :http_error,
               status: 429
             )
           )
  end
end
