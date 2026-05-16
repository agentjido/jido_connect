defmodule Jido.Connect.Airtable.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Client.Response

  describe "handle_list_bases_response/1" do
    test "returns normalized bases on success" do
      payload = fixture!("base_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, bases} = Response.handle_list_bases_response(response)
      assert length(bases) == 2
      assert hd(bases).base_id == "appLkNDIC9N0juRia"
      assert hd(bases).name == "Project Tracker"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 401, body: %{"error" => %{"message" => "Unauthorized"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_bases_response(response)
    end

    test "returns error on transport error" do
      response = {:error, :timeout}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_bases_response(response)
    end
  end

  describe "handle_get_base_response/1" do
    test "returns normalized base on success" do
      payload = fixture!("base_common.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, base} = Response.handle_get_base_response(response)
      assert base.base_id == "appLkNDIC9N0juRia"
      assert base.name == "Project Tracker"
      assert base.permission_level == "create"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 404, body: %{"error" => %{"message" => "Not found"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_get_base_response(response)
    end

    test "returns error on transport error" do
      response = {:error, :econnrefused}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_get_base_response(response)
    end
  end

  describe "handle_list_tables_response/1" do
    test "returns normalized tables on success" do
      payload = fixture!("table_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_tables_response(response)
      assert length(result.tables) == 2
      assert hd(result.tables).table_id == "tblK9MZVyNlLQRtJf"
      assert hd(result.tables).name == "Tasks"
      assert result.offset == "itrYYYYYYYYYYYY/recYYYYYYYYYYYY"
    end

    test "returns tables without offset when absent" do
      payload = %{
        "tables" => [
          %{"id" => "tbl1", "name" => "Table1", "primaryFieldId" => "fld1"}
        ]
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_tables_response(response)
      assert length(result.tables) == 1
      refute Map.has_key?(result, :offset)
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 403, body: %{"error" => %{"message" => "Forbidden"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_tables_response(response)
    end

    test "returns error on transport error" do
      response = {:error, :timeout}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_tables_response(response)
    end
  end

  describe "handle_list_records_response/1" do
    test "returns normalized records with offset on success" do
      payload = fixture!("record_list.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      assert length(result.records) == 2
      assert hd(result.records).record_id == "recK9MZVyNlLQRtJf"
      assert hd(result.records).fields["Name"] == "Design homepage"
      assert result.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
    end

    test "returns records without offset when absent" do
      payload = %{
        "records" => [
          %{"id" => "rec1", "fields" => %{"Name" => "Test"}}
        ]
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_records_response(response)
      assert length(result.records) == 1
      refute Map.has_key?(result, :offset)
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 401, body: %{"error" => %{"message" => "Unauthorized"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_records_response(response)
    end

    test "returns error on transport error" do
      response = {:error, :econnrefused}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_list_records_response(response)
    end

    test "returns error on invalid records payload" do
      payload = %{"records" => "not a list"}
      response = {:ok, %{status: 200, body: payload}}

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
               Response.handle_list_records_response(response)
    end
  end

  describe "handle_get_record_response/1" do
    test "returns normalized record on success" do
      payload = fixture!("record_common.json")
      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, record} = Response.handle_get_record_response(response)
      assert record.record_id == "recK9MZVyNlLQRtJf"
      assert record.fields["Name"] == "Design homepage"
      assert record.created_time == "2026-04-10T08:30:00.000Z"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 404, body: %{"error" => %{"message" => "Not found"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_get_record_response(response)
    end

    test "returns error on transport error" do
      response = {:error, :timeout}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_get_record_response(response)
    end
  end

  describe "handle_create_record_response/1" do
    test "returns normalized record on success" do
      payload = %{
        "id" => "recNew",
        "fields" => %{"Name" => "Created Task"},
        "createdTime" => "2026-05-15T12:00:00.000Z"
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, record} = Response.handle_create_record_response(response)
      assert record.record_id == "recNew"
      assert record.fields["Name"] == "Created Task"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 422, body: %{"error" => %{"message" => "Invalid request"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_create_record_response(response)
    end
  end

  describe "handle_update_record_response/1" do
    test "returns normalized record on success" do
      payload = %{
        "id" => "rec1",
        "fields" => %{"Name" => "Updated Task"},
        "createdTime" => "2026-04-10T08:30:00.000Z"
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, record} = Response.handle_update_record_response(response)
      assert record.record_id == "rec1"
      assert record.fields["Name"] == "Updated Task"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 404, body: %{"error" => %{"message" => "Not found"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_update_record_response(response)
    end
  end

  describe "handle_delete_record_response/1" do
    test "returns normalized record on success" do
      payload = %{
        "id" => "rec1",
        "fields" => %{},
        "deleted" => true
      }

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, record} = Response.handle_delete_record_response(response)
      assert record.record_id == "rec1"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 404, body: %{"error" => %{"message" => "Not found"}}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :airtable}} =
               Response.handle_delete_record_response(response)
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "test", "fixtures", "airtable", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
