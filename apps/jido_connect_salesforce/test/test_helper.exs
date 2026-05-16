ExUnit.start()

defmodule MockClient do
  @moduledoc false

  def get_contact(input, credentials), do: handle(:get_contact, input, credentials)
  def list_contacts(input, credentials), do: handle(:list_contacts, input, credentials)
  def create_contact(input, credentials), do: handle(:create_contact, input, credentials)

  defp handle(action, _input, _credentials) do
    case Process.get({__MODULE__, action}) do
      nil -> {:error, :not_mocked}
      result -> result
    end
  end

  def stub(responses) when is_list(responses) do
    Enum.each(responses, fn {action, result} ->
      Process.put({__MODULE__, action}, result)
    end)
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
