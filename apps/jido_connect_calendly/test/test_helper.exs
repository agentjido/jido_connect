ExUnit.start()

defmodule MockClient do
  @moduledoc false

  def list_event_types(input, token), do: handle(:list_event_types, input, token)
  def get_event_type(input, token), do: handle(:get_event_type, input, token)
  def list_scheduled_events(input, token), do: handle(:list_scheduled_events, input, token)
  def get_scheduled_event(input, token), do: handle(:get_scheduled_event, input, token)
  def list_invitees(input, token), do: handle(:list_invitees, input, token)
  def get_invitee(input, token), do: handle(:get_invitee, input, token)

  defp handle(action, _input, _token) do
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
