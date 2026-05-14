defmodule Jido.Connect.Google.Analytics.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Analytics.{Client, Dimension, Metric}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_data_api_base_url,
      "https://analytics-data.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_analytics, :google_analytics_data_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets Analytics metadata for a property" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1beta/properties/1234/metadata"
      assert conn.query_params["fields"] == "dimensions(apiName,uiName),metrics(apiName,uiName)"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, %{
        "name" => "properties/1234/metadata",
        "dimensions" => [
          %{
            "apiName" => "country",
            "uiName" => "Country",
            "description" => "The country where activity occurred.",
            "category" => "Geography",
            "customDefinition" => false
          }
        ],
        "metrics" => [
          %{
            "apiName" => "activeUsers",
            "uiName" => "Active users",
            "description" => "The number of active users.",
            "category" => "User",
            "type" => "TYPE_INTEGER",
            "customDefinition" => false
          }
        ],
        "comparisons" => [%{"apiName" => "allUsers"}]
      })
    end)

    assert {:ok,
            %{
              metadata_name: "properties/1234/metadata",
              dimensions: [%Dimension{name: "country", display_name: "Country"}],
              metrics: [%Metric{name: "activeUsers", type: "TYPE_INTEGER"}],
              comparisons: [%{"apiName" => "allUsers"}]
            }} =
             Client.get_metadata(
               %{
                 property: "properties/1234",
                 fields: "dimensions(apiName,uiName),metrics(apiName,uiName)"
               },
               "token"
             )
  end

  test "returns provider errors for invalid metadata success payloads" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"dimensions" => :invalid})
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.get_metadata(%{property: "properties/1234"}, "token")
  end
end
