defmodule Jido.Connect.Gmail.Handlers.Actions.TrashThread do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :thread_id) do
      Mutation.run_client(input, credentials, :trash_thread, :thread)
    end
  end
end
