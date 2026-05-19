defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.InspectURLTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.InspectURL
  alias Jido.Connect.Google.SearchConsole.URLInspection

  defmodule FakeURLInspectionClient do
    def inspect_url(
          %{site_url: "https://example.com/", inspection_url: "https://example.com/page"},
          "token"
        ) do
      {:ok,
       URLInspection.new!(%{
         inspection_result_link: "https://search.google.com/search-console/inspect?id=xyz",
         index_status: %{
           "verdict" => "PASS",
           "coverageState" => "Submitted and indexed"
         },
         mobile_usability_result: %{"verdict" => "PASS"},
         rich_results: []
       })}
    end

    def inspect_url(
          %{site_url: "https://example.com/", inspection_url: "https://example.com/not-indexed"},
          "token"
        ) do
      {:ok,
       URLInspection.new!(%{
         index_status: %{
           "verdict" => "NEVER_INDEXED",
           "coverageState" => "Discovered – currently not indexed"
         },
         mobile_usability_result: %{}
       })}
    end
  end

  @fake_credentials %{
    access_token: "token",
    google_search_console_client: FakeURLInspectionClient
  }

  describe "run/2 site_url validation" do
    test "returns error when site_url is missing" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{inspection_url: "https://example.com/page"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when site_url is empty string" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{site_url: "", inspection_url: "https://example.com/page"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when site_url is blank" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{site_url: "   ", inspection_url: "https://example.com/page"},
                 %{credentials: %{access_token: "token"}}
               )
    end
  end

  describe "run/2 inspection_url validation" do
    test "returns error when inspection_url is missing" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{site_url: "https://example.com/"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when inspection_url is empty string" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{site_url: "https://example.com/", inspection_url: ""},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when inspection_url is blank" do
      assert {:error, %{reason: :invalid_url_inspection_request}} =
               InspectURL.run(
                 %{site_url: "https://example.com/", inspection_url: "   "},
                 %{credentials: %{access_token: "token"}}
               )
    end
  end

  describe "run/2 with valid inputs" do
    test "returns normalized URL inspection result" do
      assert {:ok, %{inspection: inspection}} =
               InspectURL.run(
                 %{
                   site_url: "https://example.com/",
                   inspection_url: "https://example.com/page"
                 },
                 %{credentials: @fake_credentials}
               )

      assert inspection.inspection_result_link ==
               "https://search.google.com/search-console/inspect?id=xyz"

      assert inspection.index_status == %{
               "verdict" => "PASS",
               "coverageState" => "Submitted and indexed"
             }

      assert inspection.mobile_usability_result == %{"verdict" => "PASS"}
    end

    test "returns result for non-indexed URL" do
      assert {:ok, %{inspection: inspection}} =
               InspectURL.run(
                 %{
                   site_url: "https://example.com/",
                   inspection_url: "https://example.com/not-indexed"
                 },
                 %{credentials: @fake_credentials}
               )

      assert inspection.index_status["verdict"] == "NEVER_INDEXED"
    end

    test "passes language_code through to client" do
      assert {:ok, %{inspection: _inspection}} =
               InspectURL.run(
                 %{
                   site_url: "https://example.com/",
                   inspection_url: "https://example.com/page",
                   language_code: "en-US"
                 },
                 %{credentials: @fake_credentials}
               )
    end
  end
end
