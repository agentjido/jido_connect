defmodule Jido.Connect.Gmail.Handlers.Actions.ModifyThread do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :thread_id),
         {:ok, input} <- Mutation.normalize_label_mutation(input) do
      Mutation.run_client(input, credentials, :modify_thread, :thread)
    end
  end
end
