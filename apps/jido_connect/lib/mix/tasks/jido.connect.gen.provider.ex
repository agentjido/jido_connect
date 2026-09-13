defmodule Mix.Tasks.Jido.Connect.Gen.Provider do
  @moduledoc """
  Generates a minimal Jido Connect provider package scaffold.

      mix jido.connect.gen.provider acme

  By default files are written under `apps/`, matching the umbrella layout.
  Existing files are preserved. Pass `--force` to replace regular files.
  The generated package depends on the v3 Hex package by default. Pass
  `--local-path ../jido_connect` only when developing inside this umbrella.
  """

  use Mix.Task

  alias Jido.Connect.Dev.ProviderScaffold

  @shortdoc "Generates a Jido Connect provider scaffold"

  @impl Mix.Task
  def run(args) do
    case OptionParser.parse(args, strict: [force: :boolean, local_path: :string]) do
      {opts, [provider], []} ->
        paths =
          ProviderScaffold.write!("apps", provider,
            force: Keyword.get(opts, :force, false),
            local_core_path: Keyword.get(opts, :local_path)
          )

        Enum.each(paths, &Mix.shell().info("created #{&1}"))

      _other ->
        Mix.raise(
          "expected provider name, for example: mix jido.connect.gen.provider acme [--force] [--local-path ../jido_connect]"
        )
    end
  end
end
