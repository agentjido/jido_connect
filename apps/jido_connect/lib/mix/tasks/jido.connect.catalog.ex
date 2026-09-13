defmodule Mix.Tasks.Jido.Connect.Catalog do
  @moduledoc """
  Lists and searches configured Jido Connect integrations.

      mix jido.connect.catalog
      mix jido.connect.catalog --query issue
      mix jido.connect.catalog --module Jido.Connect.GitHub --format json

  Provider packages self-register through application metadata. Host apps can
  still add or override modules with:

      config :jido_connect, catalog_modules: [Jido.Connect.GitHub]
  """

  use Mix.Task

  alias Jido.Connect.Catalog

  @shortdoc "Lists searchable Jido Connect catalog entries"
  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, _invalid} =
      OptionParser.parse(args,
        strict: [
          module: :keep,
          query: :string,
          q: :string,
          status: :string,
          category: :string,
          tag: :string,
          visibility: :string,
          auth_kind: :string,
          auth_profile: :string,
          scope: :string,
          capability: :string,
          capability_kind: :string,
          resource: :string,
          verb: :string,
          tool: :string,
          format: :string
        ]
      )

    entries =
      Catalog.discover(
        modules: Keyword.get_values(opts, :module) |> default_modules(),
        query: opts[:query] || opts[:q],
        status: opts[:status],
        category: opts[:category],
        tag: opts[:tag],
        visibility: opts[:visibility],
        auth_kind: opts[:auth_kind],
        auth_profile: opts[:auth_profile],
        scope: opts[:scope],
        capability: opts[:capability],
        capability_kind: opts[:capability_kind],
        tool: opts[:tool]
      )

    case Keyword.get(opts, :format, "text") do
      "json" -> print_json(entries)
      _text -> print_text(entries)
    end
  end

  defp default_modules([]), do: Catalog.configured_modules()
  defp default_modules(modules), do: modules

  defp print_json(entries) do
    entries
    |> Enum.map(&Catalog.to_map/1)
    |> Jason.encode!(pretty: true)
    |> Mix.shell().info()
  end

  defp print_text([]) do
    Mix.shell().info("No Jido Connect catalog entries found.")
  end

  defp print_text(entries) do
    Enum.each(entries, fn entry ->
      Mix.shell().info("""
      #{entry.name} (#{entry.id})
        package: #{entry.package}
        status: #{entry.status}
        category: #{entry.category}
        auth: #{auth_modes(entry)}
        actions: #{length(entry.actions)}
        triggers: #{length(entry.triggers)}
      """)
    end)
  end

  defp auth_modes(entry) do
    entry.auth_profiles
    |> Enum.map(&"#{&1.id}:#{&1.kind}")
    |> Enum.join(", ")
  end
end
