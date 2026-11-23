defmodule Jido.Connect.Examples.StartHere.WatchPullRequests do
  @moduledoc "Receives the Signals from one GitHub poll and records the latest update."

  alias Jido.Connect.{GitHub, Plugin}
  alias Jido.Connect.GitHub.Sensors.UpdatedPullRequests
  alias Jido.Joi

  use Jido.Agent, name: "connect_watch_pull_requests", plugins: [Plugin]

  state do
    schema(Joi.object(%{latest_update: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :source, GitHub do
      triggers(["github.pull_request.updated"])
    end
  end

  routes do
    route "github.pull_request.updated", as: :record_update do
      action update,
        schema:
          Joi.object(%{
            repo: Joi.string(),
            pull_number: Joi.integer(),
            title: Joi.string(),
            state: Joi.string(),
            url: Joi.string(),
            updated_at: Joi.string()
          }) do
        {:ok, %{latest_update: update}}
      end
    end
  end

  @doc "Prepares one poll. The caller drives ticks and handles the returned schedule."
  def watch(repo, access), do: UpdatedPullRequests.init(%{repo: repo}, access)

  @doc "Supplies the current host binding and runs one tick with the last checkpoint."
  def tick(watch, access) do
    watch = Jido.Connect.Sensor.replace_context(watch, access)

    Task.async(fn -> UpdatedPullRequests.handle_event(:tick, watch) end)
    |> Task.await(20_000)
  end
end
