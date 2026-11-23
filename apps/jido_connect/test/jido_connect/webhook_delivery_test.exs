defmodule Jido.Connect.WebhookDeliveryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.WebhookDelivery

  # Depth counts from the sanitized value: the map itself is level 0, so a
  # change's `from` below is level 4 and a value inside `detail` is level 5.
  @long String.duplicate("a", 600)

  describe "to_public_map/1" do
    test "keeps normalized signal values on level 4 within the byte, collection and key limits" do
      public = delivery() |> WebhookDelivery.to_public_map()

      assert %{
               "record" => %{
                 "changes" => [
                   %{
                     "field" => "state",
                     "from" => "open",
                     "to" => nil,
                     "note" => note,
                     "token" => "[redacted]",
                     "detail" => %{"kind" => "[truncated]"},
                     "values" => values
                   }
                 ]
               }
             } = public.normalized_signal

      assert note == binary_part(@long, 0, 512) <> "...[truncated 88 bytes]"
      assert values == List.duplicate("[truncated]", 50) ++ ["[truncated 1 items]"]
      assert {:ok, _json} = Jason.encode(public)
    end

    test "keeps payload and metadata at four levels" do
      public = delivery() |> WebhookDelivery.to_public_map()

      for part <- [public.payload, public.metadata] do
        assert %{"record" => %{"changes" => [change]}} = part

        assert change == %{
                 "field" => "[truncated]",
                 "from" => "[truncated]",
                 "to" => "[truncated]",
                 "note" => "[truncated]",
                 "token" => "[redacted]",
                 "detail" => "[truncated]",
                 "values" => "[truncated]"
               }
      end
    end
  end

  defp delivery do
    WebhookDelivery.verified!(:demo,
      delivery_id: "delivery_1",
      event: "record.updated",
      payload: nested(),
      metadata: nested()
    )
    |> WebhookDelivery.put_signal(nested())
  end

  defp nested do
    %{
      record: %{
        changes: [
          %{
            field: "state",
            from: "open",
            to: nil,
            note: @long,
            token: "secret-value",
            detail: %{kind: "nested"},
            values: Enum.to_list(1..51)
          }
        ]
      }
    }
  end
end
