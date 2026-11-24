defmodule Jido.Connect.TestSupport.LiveSmokeFixturesTest do
  # Checks every committed recording and capture of the umbrella against the
  # current sanitizer: sanitizing it again changes nothing, and the leak guard
  # passes. Without credentials in the environment the guard knows only the
  # values it learns; a run with the env files of docs/live_smoke_tests.md
  # loaded also guards the credentials and configured values. Failures name
  # files and changed top-level keys, never values.
  use ExUnit.Case, async: false

  alias Jido.Connect.TestSupport.LiveSmoke
  alias Jido.Connect.TestSupport.LiveSmoke.LeakError

  @umbrella Path.expand("../../../../..", __DIR__)

  test "every recorded fixture comes out of sanitize_fixture/2 unchanged" do
    files = fixtures("recorded")

    assert problems(files, &LiveSmoke.sanitize_fixture/1) == []
  end

  test "every captured delivery comes out of sanitize_capture/2 unchanged" do
    files = fixtures("captured")
    secret = LiveSmoke.replay_secret()

    assert problems(files, &LiveSmoke.sanitize_capture(&1, secret: secret)) == []
  end

  test "no synthetic fixture holds a credential or a configured value" do
    # Synthetic fixtures are written by hand, not by the sanitizer, and keep
    # placeholder tokens under keys it redacts. The leak guard checks each
    # file as it is, so a value under such a key does not escape it.
    files = fixtures("synthetic")

    assert problems(files, &LiveSmoke.check_leaks!/1, :leaks) == []
  end

  test "names the file and the changed keys of a fixture, never a value" do
    root = Path.join(System.tmp_dir!(), "live-smoke-review-#{System.unique_integer([:positive])}")
    dir = Path.join(root, "apps/jido_connect_stub/test/fixtures/stub")
    on_exit(fn -> File.rm_rf!(root) end)

    token = "xoxb-live-smoke-review-check"
    previous = System.get_env("SLACK_BOT_TOKEN")
    System.put_env("SLACK_BOT_TOKEN", token)

    on_exit(fn ->
      if previous,
        do: System.put_env("SLACK_BOT_TOKEN", previous),
        else: System.delete_env("SLACK_BOT_TOKEN")
    end)

    write_json!(Path.join(dir, "recorded/clean.json"), envelope("person-1@example.com"))
    write_json!(Path.join(dir, "recorded/raw.json"), envelope("ada@corp.test"))

    write_json!(
      Path.join(dir, "recorded/trimmed.json"),
      Map.delete(envelope("person-1@example.com"), "headers")
    )

    write_json!(
      Path.join(dir, "recorded/bodiless.json"),
      Map.delete(envelope("person-1@example.com"), "body")
    )

    write_json!(Path.join(dir, "recorded/list.json"), [envelope("ada@corp.test")])
    write_json!(Path.join(dir, "synthetic/token.json"), %{"access_token" => token})

    assert problems(fixtures("recorded", root), &LiveSmoke.sanitize_fixture/1, :changes, root) ==
             [
               {"apps/jido_connect_stub/test/fixtures/stub/recorded/bodiless.json", ["body"]},
               {"apps/jido_connect_stub/test/fixtures/stub/recorded/list.json",
                "not a recorded fixture"},
               {"apps/jido_connect_stub/test/fixtures/stub/recorded/raw.json", ["body"]},
               {"apps/jido_connect_stub/test/fixtures/stub/recorded/trimmed.json", ["headers"]}
             ]

    assert [{"apps/jido_connect_stub/test/fixtures/stub/synthetic/token.json", message}] =
             problems(fixtures("synthetic", root), &LiveSmoke.check_leaks!/1, :leaks, root)

    assert message =~ "SLACK_BOT_TOKEN"
    refute message =~ token
  end

  defp fixtures(kind, root \\ @umbrella),
    do: Path.wildcard(Path.join(root, "apps/*/test/fixtures/*/#{kind}/*.json"))

  defp problems(files, sanitize, mode \\ :changes, root \\ @umbrella) do
    for path <- files, problem = problem(path, sanitize, mode, root), do: problem
  end

  defp problem(path, sanitize, mode, root) do
    file = Path.relative_to(path, root)
    fixture = path |> File.read!() |> Jason.decode!()

    if mode == :changes and not is_map(fixture),
      do: {file, "not a recorded fixture"},
      else: check(file, fixture, sanitize, mode)
  end

  defp check(file, fixture, sanitize, mode) do
    case sanitize.(fixture) do
      _result when mode == :leaks -> nil
      ^fixture -> nil
      changed -> {file, changed_keys(fixture, changed)}
    end
  rescue
    error in LeakError -> {file, Exception.message(error)}
  end

  # The top-level keys whose values differ or that only one side has, so a
  # failure points at the part to review without printing a value.
  defp changed_keys(fixture, changed) do
    for key <- Enum.sort(Enum.uniq(Map.keys(fixture) ++ Map.keys(changed))),
        Map.fetch(fixture, key) != Map.fetch(changed, key),
        do: key
  end

  defp envelope(email) do
    %{
      "body" => %{"email" => email},
      "headers" => %{"content-type" => ["application/json"]},
      "recorded_at" => "2026-11-12",
      "request" => %{"method" => "GET", "path" => "/v1/profile"},
      "status" => 200
    }
  end

  defp write_json!(path, value) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(value))
  end
end
