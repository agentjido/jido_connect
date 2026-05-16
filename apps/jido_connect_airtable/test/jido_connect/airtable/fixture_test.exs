defmodule Jido.Connect.Airtable.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.Normalizer

  describe "base fixtures" do
    test "normalizes common base fixture" do
      payload = fixture!("base_common.json")

      assert {:ok, base} = Normalizer.base(payload)
      assert base.base_id == "appLkNDIC9N0juRia"
      assert base.name == "Project Tracker"
      assert base.permission_level == "create"
      assert base.description == "A base for tracking projects and tasks."
    end

    test "normalizes base list fixture" do
      payload = fixture!("base_list.json")

      assert {:ok, pagination} = Normalizer.pagination(payload)
      assert pagination.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
    end

    test "normalizes each base in list fixture" do
      payload = fixture!("base_list.json")

      bases = payload["bases"]

      assert {:ok, base1} = Normalizer.base(Enum.at(bases, 0))
      assert base1.base_id == "appLkNDIC9N0juRia"
      assert base1.name == "Project Tracker"

      assert {:ok, base2} = Normalizer.base(Enum.at(bases, 1))
      assert base2.base_id == "appX9k2mPqR4vWnjz"
      assert base2.name == "CRM"
    end
  end

  describe "table fixtures" do
    test "normalizes common table fixture" do
      payload = fixture!("table_common.json")

      assert {:ok, table} = Normalizer.table(payload)
      assert table.table_id == "tblK9MZVyNlLQRtJf"
      assert table.name == "Tasks"
      assert table.description == "Active project tasks."
      assert table.primary_field_id == "fld1VnoyuotSTyxXI"
    end

    test "normalizes each table in list fixture" do
      payload = fixture!("table_list.json")

      tables = payload["tables"]

      assert {:ok, table1} = Normalizer.table(Enum.at(tables, 0))
      assert table1.table_id == "tblK9MZVyNlLQRtJf"
      assert table1.name == "Tasks"
      assert table1.description == "Active project tasks."

      assert {:ok, table2} = Normalizer.table(Enum.at(tables, 1))
      assert table2.table_id == "tblX7jN4pQrK2mWab"
      assert table2.name == "People"
      assert table2.description == "Team members."
    end
  end

  describe "field fixtures" do
    test "normalizes common field fixture" do
      payload = fixture!("field_common.json")

      assert {:ok, field} = Normalizer.field(payload)
      assert field.field_id == "fld1VnoyuotSTyxXI"
      assert field.name == "Name"
      assert field.type == "singleLineText"
      assert field.description == "The task title."
    end
  end

  describe "view fixtures" do
    test "normalizes common view fixture" do
      payload = fixture!("view_common.json")

      assert {:ok, view} = Normalizer.view(payload)
      assert view.view_id == "viwK9MZVyNlLQRtJf"
      assert view.name == "Grid view"
      assert view.type == "grid"
      assert view.description == "Default grid view for all tasks."
    end
  end

  describe "record fixtures" do
    test "normalizes common record fixture" do
      payload = fixture!("record_common.json")

      assert {:ok, record} = Normalizer.record(payload)
      assert record.record_id == "recK9MZVyNlLQRtJf"
      assert record.created_time == "2026-04-10T08:30:00.000Z"

      fields = record.fields
      assert fields["Name"] == "Design homepage"
      assert fields["Status"] == "In progress"
      assert fields["Priority"] == "High"
    end

    test "normalizes record list fixture" do
      payload = fixture!("record_list.json")

      records = payload["records"]

      assert {:ok, record} = Normalizer.record(Enum.at(records, 0))
      assert record.record_id == "recK9MZVyNlLQRtJf"

      assert {:ok, record} = Normalizer.record(Enum.at(records, 1))
      assert record.record_id == "recX7jN4pQrK2mWab"
    end

    test "normalizes record list fixture with pagination" do
      payload = fixture!("record_list.json")

      assert {:ok, pagination} = Normalizer.pagination(payload)
      assert pagination.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
    end
  end

  describe "attachment fixtures" do
    test "normalizes common attachment fixture" do
      payload = fixture!("attachment_common.json")

      assert {:ok, attachment} = Normalizer.attachment(payload)
      assert attachment.attachment_id == "attPH6wAnRP5OC3bk"
      assert attachment.filename == "wireframe.pdf"
      assert attachment.mime_type == "application/pdf"
      assert attachment.size == 204_800
      assert attachment.url == "https://content.airtable.com/attachments/example.pdf"
    end
  end

  describe "comment fixtures" do
    test "normalizes common comment fixture" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.comment_id == "comK9MZVyNlLQRtJf"
      assert comment.text == "Should we update the deadline for this task?"
      assert comment.created_time == "2026-04-12T14:30:00.000Z"

      assert comment.author["id"] == "usrL4jN2pQrK8mWab"
      assert comment.author["name"] == "Alice Johnson"

      assert comment.metadata.mentioned != nil
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, pagination} = Normalizer.pagination(payload)
      assert pagination.offset == "itrXXXXXXXXXXXX/recXXXXXXXXXXXX"
    end
  end

  describe "invalid payloads" do
    test "returns error for non-map payloads" do
      assert {:error, :invalid_base_payload} = Normalizer.base("not a map")
      assert {:error, :invalid_table_payload} = Normalizer.table(nil)
      assert {:error, :invalid_field_payload} = Normalizer.field(nil)
      assert {:error, :invalid_view_payload} = Normalizer.view(nil)
      assert {:error, :invalid_record_payload} = Normalizer.record(nil)
      assert {:error, :invalid_attachment_payload} = Normalizer.attachment(nil)
      assert {:error, :invalid_comment_payload} = Normalizer.comment(nil)
      assert {:error, :invalid_pagination_payload} = Normalizer.pagination(nil)
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "airtable", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
