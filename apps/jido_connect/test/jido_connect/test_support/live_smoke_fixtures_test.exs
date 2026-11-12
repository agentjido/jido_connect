defmodule Jido.Connect.TestSupport.LiveSmokeFixturesTest do
  # Checks every committed recording and capture of the umbrella against the
  # current sanitizer: sanitizing it again changes nothing, and the leak guard
  # passes. Without credentials in the environment the guard knows only the
  # values it learns; a run with the env files of docs/live_smoke_tests.md
  # loaded also guards the credentials and configured values. Failures name
  # files and changed top-level keys, never values.
  use ExUnit.Case, async: true

  alias Jido.Connect.TestSupport.LiveSmoke
  alias Jido.Connect.TestSupport.LiveSmoke.LeakError

  @umbrella Path.expand("../../../../..", __DIR__)

  test "every recorded fixture comes out of sanitize_fixture/2 unchanged" do
    files = fixtures("recorded")
    assert length(files) > 100

    assert problems(files, &LiveSmoke.sanitize_fixture/1) == []
  end

  test "every captured delivery comes out of sanitize_capture/2 unchanged" do
    files = fixtures("captured")
    assert length(files) > 10
    secret = LiveSmoke.replay_secret()

    assert problems(files, &LiveSmoke.sanitize_capture(&1, secret: secret)) == []
  end

  test "no synthetic fixture holds a credential or a configured value" do
    # Synthetic fixtures are written by hand, not by the sanitizer, and keep
    # placeholder tokens under keys it redacts. The leak guard checks each
    # file as it is, so a value under such a key does not escape it.
    files = fixtures("synthetic")
    assert files != []

    assert problems(files, &LiveSmoke.check_leaks!/1, :leaks) == []
  end

  defp fixtures(kind),
    do: Path.wildcard(Path.join(@umbrella, "apps/*/test/fixtures/*/#{kind}/*.json"))

  defp problems(files, sanitize, mode \\ :changes) do
    for path <- files, problem = problem(path, sanitize, mode), do: problem
  end

  defp problem(path, sanitize, mode) do
    file = Path.relative_to(path, @umbrella)
    fixture = path |> File.read!() |> Jason.decode!()

    try do
      case sanitize.(fixture) do
        _result when mode == :leaks -> nil
        ^fixture -> nil
        changed -> {file, changed_keys(fixture, changed)}
      end
    rescue
      error in LeakError -> {file, Exception.message(error)}
    end
  end

  # The top-level keys whose values differ, so a failure points at the part
  # to review without printing a value.
  defp changed_keys(fixture, changed),
    do: for({key, value} <- fixture, changed[key] != value, do: key)
end
