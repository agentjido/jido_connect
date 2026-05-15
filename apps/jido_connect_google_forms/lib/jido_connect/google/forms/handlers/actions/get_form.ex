defmodule Jido.Connect.Google.Forms.Handlers.Actions.GetForm do
  @moduledoc false

  def run(_input, %{credentials: _credentials}) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       reason: :not_implemented,
       message: "GetForm handler not yet implemented"
     }}
  end
end
