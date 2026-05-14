defmodule Jido.Connect.Gmail.Handlers.Actions.UpdateLabel do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, input} <- Mutation.normalize_required_id(input, :label_id),
         {:ok, input} <- Mutation.normalize_label_update(input) do
      Mutation.run_client(input, credentials, :update_label, :label)
    end
  end
end
