defmodule Jido.Connect.Gmail.Handlers.Actions.BatchModifyMessages do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_ids(input, :message_ids),
         {:ok, input} <- Mutation.normalize_label_mutation(input) do
      Mutation.run_client(input, credentials, :batch_modify_messages, :result)
    end
  end
end
