defmodule Jido.Connect.Gmail.Handlers.Actions.DeleteMessage do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :message_id) do
      Mutation.run_client(input, credentials, :delete_message, :result)
    end
  end
end
