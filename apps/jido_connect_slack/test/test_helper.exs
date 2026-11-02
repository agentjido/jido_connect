ExUnit.start(exclude: [:live_smoke])

unless Code.ensure_loaded?(Jido.Connect.TestSupport.LiveSmoke) do
  Code.require_file("../../jido_connect/test/support/live_smoke.ex", __DIR__)
end

unless Code.ensure_loaded?(Jido.Connect.Slack.TestSupport.LiveSlack) do
  Code.require_file("support/live_slack.ex", __DIR__)
end

unless Code.ensure_loaded?(Jido.Connect.Slack.TestSupport.CapturedDelivery) do
  Code.require_file("support/captured_delivery.ex", __DIR__)
end
