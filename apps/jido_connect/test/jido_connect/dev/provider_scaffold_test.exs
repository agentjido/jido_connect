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

  test "standalone scaffolds use Hex and local development needs an explicit path" do
    default_mix =
      ProviderScaffold.files("acme")
      |> Enum.find(&String.ends_with?(&1.path, "/mix.exs"))
      |> Map.fetch!(:contents)

    local_mix =
      ProviderScaffold.files("acme", local_core_path: "../jido_connect")
      |> Enum.find(&String.ends_with?(&1.path, "/mix.exs"))
      |> Map.fetch!(:contents)

    assert default_mix =~ ~s({:jido_connect, "~> 3.0"})
    refute default_mix =~ "path:"
    assert local_mix =~ ~s({:jido_connect, path: "../jido_connect"})
  end

  test "generated package metadata registers its provider for catalog discovery" do
    mix_file =
      ProviderScaffold.files("acme_generated")
      |> Enum.find(&String.ends_with?(&1.path, "/mix.exs"))

    {_, application_bodies} =
      mix_file.contents
      |> Code.string_to_quoted!()
      |> Macro.prewalk([], fn
        {:def, _, [{:application, _, _}, [do: body]]} = node, found ->
          {node, [body | found]}

        node, found ->
          {node, found}
      end)

    [body] = application_bodies
    {application_config, _bindings} = Code.eval_quoted(body)
    provider = Jido.Connect.AcmeGenerated
    assert application_config[:env] == [jido_connect_providers: [provider]]

    app = :jido_connect_acme_generated_scaffold_test

    assert :ok =
             :application.load(
               {:application, app,
                [
                  description: ~c"Scaffold registration test",
                  vsn: ~c"0.0.0",
                  modules: [],
                  registered: [],
                  applications: [:kernel, :stdlib],
                  env: application_config[:env]
                ]}
             )

    on_exit(fn -> :application.unload(app) end)
    assert provider in Jido.Connect.Catalog.registered_modules()
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

      Mix.Tasks.Jido.Connect.Gen.Provider.run([
        "acme",
        "--force",
        "--local-path",
        "../jido_connect"
      ])

      assert File.read!(target) =~ ~s({:jido_connect, path: "../jido_connect"})
    end)
  end

  defp temp_root do
    root =
      Path.join(System.tmp_dir!(), "jido-connect-scaffold-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(root) end)
    root
  end
end
