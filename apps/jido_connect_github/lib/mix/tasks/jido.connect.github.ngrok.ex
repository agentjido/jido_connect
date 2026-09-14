defmodule Mix.Tasks.Jido.Connect.Github.Ngrok do
  @moduledoc """
  Starts an ngrok tunnel for the local GitHub demo host.

      mix jido.connect.github.ngrok
      mix jido.connect.github.ngrok --port 4001

  This is a convenience wrapper around `mix jido.connect.ngrok`. The GitHub
  manifest task prints GitHub callback and webhook URLs.
  """

  use Mix.Task

  @shortdoc "Starts an ngrok tunnel for GitHub integration demos"

  @impl Mix.Task
  def run(args) do
    Mix.Tasks.Jido.Connect.Ngrok.run(args)
  end
end
