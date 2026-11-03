defmodule Jido.Connect.Slack.TestSupport.SyntheticFixture do
  @moduledoc false

  # Provider responses written from Slack's documentation, for calls that
  # the test workspace cannot record, such as `oauth.v2.access`, which needs
  # the app's client secret. They live in test/fixtures/slack/synthetic,
  # apart from the recordings and captures. Each file names its `source`
  # (URL, section, retrieval date) and has no `recorded_at`; its token values
  # are placeholders.

  import ExUnit.Assertions

  @dir Path.expand("../fixtures/slack/synthetic", __DIR__)

  @doc "Returns the synthetic response `name` with its source, request and status."
  def fixture!(name) do
    fixture = @dir |> Path.join("#{name}.json") |> File.read!() |> Jason.decode!()

    assert %{"source" => %{"kind" => "synthetic", "url" => "https://" <> _}} = fixture,
           "#{name} names no source"

    refute Map.has_key?(fixture, "recorded_at"), "#{name} claims to be a recording"
    fixture
  end

  @doc "Returns the body of the synthetic response `name`, unchanged, for `Req.Test.json/2`."
  def body!(name), do: name |> fixture!() |> Map.fetch!("body")
end
