defmodule Jido.Connect.Gmail.Handlers.Actions.DeleteLabel do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :label_id) do
      Mutation.run_client(input, credentials, :delete_label, :result)
    end
  end
end
