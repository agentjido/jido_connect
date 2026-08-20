defmodule Jido.Connect.X.Router do
  @moduledoc false

  def tool(descriptor), do: descriptor.tool

  def arguments(%{id: "x.account.get"}, _input, _account), do: %{}

  def arguments(%{id: action}, input, %{id: account_id})
      when action in ["x.bookmark.list", "x.post.list"] do
    %{id: account_id, max_results: input.max_results}
    |> maybe_put(:pagination_token, input.pagination_token)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
