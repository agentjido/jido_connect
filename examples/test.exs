{opts, paths, invalid} = OptionParser.parse(System.argv(), strict: [warnings_as_errors: :boolean])

if invalid != [], do: Mix.raise("Unknown example test options: #{inspect(invalid)}")

root = Path.expand(__DIR__)
paths = if paths == [], do: [root], else: Enum.map(paths, &Path.expand/1)

files =
  paths
  |> Enum.flat_map(fn path ->
    unless path == root or String.starts_with?(path, root <> "/") do
      Mix.raise("Example tests must be inside examples/: #{path}")
    end

    tests =
      cond do
        File.dir?(path) -> Path.wildcard(Path.join(path, "**/*_test.exs"))
        String.ends_with?(path, "_test.exs") and File.regular?(path) -> [path]
        true -> []
      end

    if tests == [], do: Mix.raise("No example tests match #{path}")
    tests
  end)
  |> Enum.uniq()
  |> Enum.sort()

Code.require_file("00_start_here/support/load.exs", __DIR__)
ExUnit.start()

case Kernel.ParallelCompiler.require(files, return_diagnostics: true) do
  {:ok, _modules, %{compile_warnings: compile, runtime_warnings: runtime}} ->
    if opts[:warnings_as_errors] and (compile != [] or runtime != []),
      do: Mix.raise("Example compilation emitted warnings")

  {:error, _errors, _diagnostics} ->
    Mix.raise("Example compilation failed")
end
