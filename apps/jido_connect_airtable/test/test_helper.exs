ExUnit.start()

defmodule MockClient do
  @moduledoc false

  def list_bases(input, token), do: handle(:list_bases, input, token)
  def get_base(input, token), do: handle(:get_base, input, token)
  def list_tables(input, token), do: handle(:list_tables, input, token)
  def list_records(input, token), do: handle(:list_records, input, token)
  def get_record(input, token), do: handle(:get_record, input, token)
  def create_record(input, token), do: handle(:create_record, input, token)
  def update_record(input, token), do: handle(:update_record, input, token)
  def delete_record(input, token), do: handle(:delete_record, input, token)

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
