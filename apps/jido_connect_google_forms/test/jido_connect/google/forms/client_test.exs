defmodule Jido.Connect.Google.Forms.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Forms.{Client, Form}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_forms,
      :google_forms_api_base_url,
      "https://forms.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_forms, :google_forms_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets form" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/forms/1ABCdefGHI"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, form_payload())
    end)

    assert {:ok, %Form{} = form} =
             Client.get_form(%{form_id: "1ABCdefGHI"}, "token")

    assert form.form_id == "1ABCdefGHI"
    assert form.title == "Customer Survey"
  end

  test "gets form with include linked sheets" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/forms/1ABCdefGHI"
      assert conn.query_params["includeLinkedSheets"] == "true"

      Req.Test.json(conn, form_payload())
    end)

    assert {:ok, %Form{} = form} =
             Client.get_form(
               %{form_id: "1ABCdefGHI", include_linked_sheets: true},
               "token"
             )

    assert form.form_id == "1ABCdefGHI"
  end

  test "creates form" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/forms"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "info" => %{
                 "title" => "New Survey",
                 "description" => "Tell us what you think."
               }
             }

      Req.Test.json(conn, %{
        "formId" => "1NEW_form_id",
        "info" => %{
          "title" => "New Survey",
          "description" => "Tell us what you think."
        },
        "revisionId" => "rev001"
      })
    end)

    assert {:ok, %Form{} = form} =
             Client.create_form(
               %{title: "New Survey", description: "Tell us what you think."},
               "token"
             )

    assert form.form_id == "1NEW_form_id"
    assert form.title == "New Survey"
  end

  test "creates form without description" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/forms"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "info" => %{
                 "title" => "Quick Poll"
               }
             }

      Req.Test.json(conn, %{
        "formId" => "1QUICK_form_id",
        "info" => %{
          "title" => "Quick Poll"
        },
        "revisionId" => "rev001"
      })
    end)

    assert {:ok, %Form{} = form} =
             Client.create_form(%{title: "Quick Poll"}, "token")

    assert form.form_id == "1QUICK_form_id"
    assert form.title == "Quick Poll"
  end

  test "rejects malformed form response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.get_form(%{form_id: "1ABCdefGHI"}, "token")
  end

  test "handles API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => %{"message" => "not found"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 404}} =
             Client.get_form(%{form_id: "nonexistent"}, "token")
  end

  test "batch updates form" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/forms/1ABCdefGHI:batchUpdate"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == [%{"updateFormTitle" => %{"title" => "Updated"}}]
      assert decoded["writeControl"] == %{"requiredRevisionId" => "rev001"}

      Req.Test.json(conn, %{
        "formId" => "1ABCdefGHI",
        "replies" => [%{"updateFormTitle" => %{}}]
      })
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 form_id: "1ABCdefGHI",
                 requests: [%{updateFormTitle: %{title: "Updated"}}],
                 write_control: %{requiredRevisionId: "rev001"}
               },
               "token"
             )

    assert result.form_id == "1ABCdefGHI"
    assert length(result.replies) == 1
  end

  test "batch updates form without write control" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/forms/1ABCdefGHI:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == [%{"updateFormTitle" => %{"title" => "Updated"}}]
      refute Map.has_key?(decoded, "writeControl")

      Req.Test.json(conn, %{
        "formId" => "1ABCdefGHI",
        "replies" => []
      })
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 form_id: "1ABCdefGHI",
                 requests: [%{updateFormTitle: %{title: "Updated"}}]
               },
               "token"
             )

    assert result.form_id == "1ABCdefGHI"
    assert result.replies == []
  end

  test "handles batch update API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => %{"message" => "bad request"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 400}} =
             Client.batch_update(
               %{form_id: "1ABCdefGHI", requests: [%{updateFormTitle: %{}}]},
               "token"
             )
  end

  test "handles batch update malformed response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.batch_update(
               %{form_id: "1ABCdefGHI", requests: [%{updateFormTitle: %{}}]},
               "token"
             )
  end

  defp form_payload do
    %{
      "formId" => "1ABCdefGHI",
      "info" => %{
        "title" => "Customer Survey",
        "description" => "Tell us what you think."
      },
      "revisionId" => "rev001"
    }
  end
end
