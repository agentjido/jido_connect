defmodule Jido.Connect.Dev.ProviderScaffoldTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Dev.ProviderScaffold

  test "provider scaffold returns conventional package files" do
    files = ProviderScaffold.files("google_sheets")
    paths = Enum.map(files, & &1.path)

    assert "jido_connect_google_sheets/mix.exs" in paths

    assert "jido_connect_google_sheets/lib/jido_connect/google_sheets/integration.ex" in paths
    assert "jido_connect_google_sheets/lib/jido_connect/google_sheets/actions/example.ex" in paths

    integration_file =
      Enum.find(files, &(&1.path =~ "integration.ex"))

    assert integration_file.contents =~ "defmodule Jido.Connect.GoogleSheets"
    assert integration_file.contents =~ "use Jido.Connect,"
    assert integration_file.contents =~ "catalog do"
    assert integration_file.contents =~ "policies do"

    action_file =
      Enum.find(files, &(&1.path =~ "actions/example.ex"))

    assert action_file.contents =~ "use Spark.Dsl.Fragment, of: Jido.Connect"
    assert action_file.contents =~ "data_classification :workspace_metadata"
  end

  test "a conflict on the last path prevents every scaffold write" do
    root = temp_root()
    files = ProviderScaffold.files("acme")
    first_path = Path.join(root, hd(files).path)
    last_path = Path.join(root, List.last(files).path)

    last_path |> Path.dirname() |> File.mkdir_p!()
    File.write!(last_path, "hand-edited test")

    assert_raise ArgumentError, ~r/scaffold files cannot be written/, fn ->
      ProviderScaffold.write!(root, "acme")
    end

    assert File.read!(last_path) == "hand-edited test"
    refute File.exists?(first_path)
  end

  test "force replaces regular scaffold files after an explicit request" do
    root = temp_root()
    paths = ProviderScaffold.write!(root, "acme")
    edited_path = List.last(paths)
    File.write!(edited_path, "hand-edited test")

    assert paths == ProviderScaffold.write!(root, "acme", force: true)
    refute File.read!(edited_path) == "hand-edited test"
  end

  test "force does not follow a symbolic link at a scaffold target" do
    root = temp_root()
    outside = Path.join(root, "preserved.txt")
    target = Path.join(root, hd(ProviderScaffold.files("acme")).path)
    File.mkdir_p!(Path.dirname(target))
    File.write!(outside, "keep this file")
    File.ln_s!(outside, target)

    assert_raise ArgumentError, ~r/scaffold files cannot be written/, fn ->
      ProviderScaffold.write!(root, "acme", force: true)
    end

    assert File.read!(outside) == "keep this file"
  end

  test "task uses --force only when the author requests replacement" do
    root = temp_root()
    File.mkdir_p!(root)

    File.cd!(root, fn ->
      Mix.Tasks.Jido.Connect.Gen.Provider.run(["acme"])
      target = Path.join(["apps", "jido_connect_acme", "mix.exs"])
      File.write!(target, "hand-edited mix file")

      assert_raise ArgumentError, ~r/scaffold files cannot be written/, fn ->
        Mix.Tasks.Jido.Connect.Gen.Provider.run(["acme"])
      end

      assert File.read!(target) == "hand-edited mix file"
      Mix.Tasks.Jido.Connect.Gen.Provider.run(["acme", "--force"])
      refute File.read!(target) == "hand-edited mix file"
    end)
  end

  defp temp_root do
    root =
      Path.join(System.tmp_dir!(), "jido-connect-scaffold-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(root) end)
    root
  end
end
