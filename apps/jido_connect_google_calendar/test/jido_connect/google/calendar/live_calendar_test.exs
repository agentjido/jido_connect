defmodule Jido.Connect.Google.Calendar.LiveCalendarTest do
  use ExUnit.Case, async: false

  # `LiveCalendar.record_attempt/2` lets the live tests retry a poll although
  # recording never replaces a file. No request is sent here; the files stand
  # for what a recording run would have written.

  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  @dir Path.expand("../../../fixtures/google_calendar/recorded", __DIR__)

  setup do
    name = "live_calendar_attempt_#{System.unique_integer([:positive])}"
    record = System.get_env("JIDO_CONNECT_RECORD")
    options = Application.get_env(:jido_connect_google, :google_req_options)

    System.put_env("JIDO_CONNECT_RECORD", "1")
    Application.put_env(:jido_connect_google, :google_req_options, retry: false)

    on_exit(fn ->
      if record,
        do: System.put_env("JIDO_CONNECT_RECORD", record),
        else: System.delete_env("JIDO_CONNECT_RECORD")

      if options,
        do: Application.put_env(:jido_connect_google, :google_req_options, options),
        else: Application.delete_env(:jido_connect_google, :google_req_options)

      for path <- Path.wildcard(Path.join(@dir, "#{name}*.json")), do: File.rm!(path)
    end)

    {:ok, name: name}
  end

  test "the first attempt refuses to start while any file of the name exists", %{name: name} do
    page = Path.join(@dir, "#{name}.2.json")
    File.write!(page, "{}")

    assert_raise File.Error, ~r/file already exists/, fn ->
      LiveCalendar.record_attempt(name, 1)
    end

    assert File.exists?(page)
  end

  test "a later attempt removes the files of the earlier ones and no other", %{name: name} do
    assert :ok = LiveCalendar.record_attempt(name, 1)

    written = for file <- ["#{name}.json", "#{name}.2.json"], do: Path.join(@dir, file)
    other = Path.join(@dir, "#{name}_other.json")
    for path <- [other | written], do: File.write!(path, "{}")

    assert :ok = LiveCalendar.record_attempt(name, 2)
    refute Enum.any?(written, &File.exists?/1)
    assert File.exists?(other)
  end
end
