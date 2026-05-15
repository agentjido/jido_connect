defmodule Jido.Connect.Google.Slides.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Slides.{Client, Presentation}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_slides,
      :google_slides_api_base_url,
      "https://slides.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_slides, :google_slides_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets presentation" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/presentations/pres_abc123"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, presentation_payload())
    end)

    assert {:ok, %Presentation{} = presentation} =
             Client.get_presentation(%{presentation_id: "pres_abc123"}, "token")

    assert presentation.presentation_id == "pres_abc123"
    assert presentation.title == "Q4 Strategy Review"
  end

  test "gets presentation with fields parameter" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/presentations/pres_abc123"
      assert conn.query_params["fields"] == "presentationId,title"

      Req.Test.json(conn, presentation_payload())
    end)

    assert {:ok, %Presentation{} = presentation} =
             Client.get_presentation(
               %{presentation_id: "pres_abc123", fields: "presentationId,title"},
               "token"
             )

    assert presentation.presentation_id == "pres_abc123"
  end

  test "creates presentation" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/presentations"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "title" => "New Q4 Strategy Review"
             }

      Req.Test.json(conn, %{
        "presentationId" => "pres_new001",
        "title" => "New Q4 Strategy Review",
        "revisionId" => "rev001"
      })
    end)

    assert {:ok, %Presentation{} = presentation} =
             Client.create_presentation(%{title: "New Q4 Strategy Review"}, "token")

    assert presentation.presentation_id == "pres_new001"
    assert presentation.title == "New Q4 Strategy Review"
  end

  test "rejects malformed presentation response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.get_presentation(%{presentation_id: "pres_abc123"}, "token")
  end

  test "handles API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => %{"message" => "not found"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 404}} =
             Client.get_presentation(%{presentation_id: "nonexistent"}, "token")
  end

  test "handles create API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 403, Jason.encode!(%{"error" => %{"message" => "forbidden"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 403}} =
             Client.create_presentation(%{title: "Blocked"}, "token")
  end

  test "handles create malformed response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.create_presentation(%{title: "Bad Response"}, "token")
  end

  defp presentation_payload do
    %{
      "presentationId" => "pres_abc123",
      "title" => "Q4 Strategy Review",
      "revisionId" => "rev001"
    }
  end
end
