defmodule Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Analytics.Dimension
  alias Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpers

  test "normalizes metadata input" do
    assert {:ok, %{property: "properties/1234", fields: "dimensions(apiName)"}} =
             ResourceHelpers.metadata_input(%{
               property: " 1234 ",
               fields: " dimensions(apiName) "
             })

    assert {:ok, %{property: "properties/1234"}} =
             ResourceHelpers.metadata_input(%{property: "properties/1234"})
  end

  test "rejects invalid metadata property input" do
    assert {:error, %Error.ValidationError{reason: :invalid_property}} =
             ResourceHelpers.metadata_input(%{property: " "})

    assert {:error, %Error.ValidationError{reason: :invalid_property}} =
             ResourceHelpers.metadata_input(%{})
  end

  test "fetches injected or default clients" do
    assert {:ok, FakeAnalyticsClient} =
             ResourceHelpers.fetch_client(%{google_analytics_client: FakeAnalyticsClient})

    assert {:ok, Jido.Connect.Google.Analytics.Client} = ResourceHelpers.fetch_client(%{})
  end

  test "converts structs to public maps" do
    assert %{name: "country"} =
             ResourceHelpers.public_map(Dimension.new!(%{name: "country"}))

    assert %{ok: true} = ResourceHelpers.public_map(%{ok: true})
    assert :ok = ResourceHelpers.public_map(:ok)
  end
end
