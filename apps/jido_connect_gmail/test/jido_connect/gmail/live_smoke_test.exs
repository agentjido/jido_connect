defmodule Jido.Connect.Gmail.LiveSmokeTest do
  @moduledoc """
  Live self-test of the harness against the Google Workspace test account:
  the client reads the mailbox profile. Its recording, `profile.json`, is the
  profile that the offline tests of the change poll read.

      mix test --only live_smoke

  The test reads `GOOGLE_ACCESS_TOKEN`. The capability checks live in the
  `*_live_smoke_test.exs` files beside this one, one file per capability
  family; see `docs/live_smoke_tests.md` for the variables and the recording
  mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Gmail.Client

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "reads the mailbox profile", %{env: env} do
    LiveSmoke.record({:jido_connect_google, :google_req_options}, :gmail, "profile")

    assert {:ok, profile} = Client.get_profile(%{}, env["GOOGLE_ACCESS_TOKEN"])
    assert is_map(profile)
  end
end
