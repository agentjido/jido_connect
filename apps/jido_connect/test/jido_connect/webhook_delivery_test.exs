defmodule Jido.Connect.WebhookDeliveryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.WebhookDelivery

  test "the public map and inspect keep deeply nested GitHub author details truncated" do
    delivery =
      WebhookDelivery.verified!(:github, event: "push")
      |> WebhookDelivery.put_signal(%{
        commits: [
          %{author: %{email: "fixture-author@example.test"}, added: ["private/path"]}
        ]
      })

    public = WebhookDelivery.to_public_map(delivery)

    assert %{
             "commits" => [
               %{
                 "author" => %{"email" => "[truncated]"},
                 "added" => ["[truncated]"]
               }
             ]
           } = public.normalized_signal

    refute inspect(delivery) =~ "fixture-author@example.test"
    refute inspect(delivery) =~ "private/path"
  end
end
