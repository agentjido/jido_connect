defmodule Jido.Connect.Gmail.Handlers.Actions.BatchDeleteMessages do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_ids(input, :message_ids) do
      Mutation.run_client(input, credentials, :batch_delete_messages, :result)
    end
  end
end
