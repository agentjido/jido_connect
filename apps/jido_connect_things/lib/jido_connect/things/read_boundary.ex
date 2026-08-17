defmodule Jido.Connect.Things.ReadBoundary do
  @moduledoc false

  alias Jido.Connect.Things.{Client, Reader, Runtime}

  def state(context, lease) do
    runtime = Runtime.runtime_context(context)

    with {:ok, client} <- Client.from_runtime(context, lease, runtime),
         {:ok, account, history} <- Reader.snapshot(client),
         {:ok, state} <- Reader.load_state(client, account, history) do
      {:ok, state}
    end
  end
end
