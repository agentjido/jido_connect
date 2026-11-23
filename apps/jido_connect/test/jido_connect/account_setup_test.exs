defmodule Jido.Connect.AccountSetupTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{AccountSetup, Error}
  alias Jido.Connect.AccountSetup.Credential

  defmodule Provider do
    @behaviour AccountSetup

    @impl true
    def authorize_url(opts), do: "https://provider.example/authorize?" <> URI.encode_query(opts)

    @impl true
    def exchange_code(_code, opts) do
      send(Keyword.fetch!(opts, :test_pid), :exchanged)
      {:ok, %Credential{fields: %{access_token: "secret"}, scopes: ["read"]}}
    end

    @impl true
    def start_device(_opts) do
      {:ok,
       %{
         device_code: "secret-device-code",
         user_code: "USER-CODE",
         verification_uri: "https://provider.example/device",
         expires_in: 120,
         interval: 5
       }}
    end

    @impl true
    def poll_device(_device_code, opts) do
      send(Keyword.fetch!(opts, :test_pid), :polled)
      {:pending, :slow_down}
    end
  end

  test "the browser transaction binds the exact OAuth client and callback" do
    opts = [client_id: "provider-client", redirect_uri: "https://app.example/oauth/provider"]
    assert {:ok, _url, flow} = AccountSetup.start_browser(Provider, "tenant/user", "reader", opts)
    refute inspect(flow) =~ flow.verifier

    consume = fn "tenant/user", state when state == flow.state -> {:ok, flow} end
    opts = Keyword.put(opts, :test_pid, self())

    for mismatch <- [client_id: "other-client", redirect_uri: "https://app.example/oauth/other"] do
      assert {:error, %Error.AuthError{reason: :invalid_oauth_state}} =
               AccountSetup.finish_browser(
                 Provider,
                 "tenant/user",
                 flow.state,
                 "callback-code",
                 consume,
                 Keyword.merge(opts, [mismatch])
               )
    end

    refute_received :exchanged
  end

  test "device polling respects the provider interval and slow down response" do
    opts = [client_id: "provider-client", test_pid: self()]
    assert {:ok, flow} = AccountSetup.start_device(Provider, opts)
    refute inspect(flow) =~ "secret-device-code"

    assert {:pending, delay, ^flow} = AccountSetup.poll_device(flow, opts)
    assert delay in 1..5_000
    refute_received :polled

    due = %{flow | next_poll_at: System.monotonic_time(:millisecond)}
    assert {:pending, 10_000, %{interval_ms: 10_000}} = AccountSetup.poll_device(due, opts)
    assert_received :polled
  end
end
