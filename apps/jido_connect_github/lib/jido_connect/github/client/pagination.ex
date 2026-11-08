defmodule Jido.Connect.GitHub.Client.Pagination do
  @moduledoc false

  alias Jido.Connect.Error

  def validate(params) when is_map(params) do
    page = Map.get(params, :page, 1)
    per_page = Map.get(params, :per_page, 100)

    if is_integer(page) and page in 1..100 and is_integer(per_page) and per_page in 1..100 do
      {:ok, %{page: page, per_page: per_page}}
    else
      {:error,
       Error.validation("GitHub page parameters are outside the supported range",
         reason: :invalid_pagination,
         subject: :pagination
       )}
    end
  end

  def metadata(%{page: page, per_page: per_page}, item_count, total_count \\ nil) do
    %{
      number: page,
      per_page: per_page,
      item_count: item_count,
      complete: complete?(page, per_page, item_count, total_count)
    }
  end

  defp complete?(_page, per_page, item_count, _total_count) when item_count < per_page, do: true

  defp complete?(page, per_page, _item_count, total_count) when is_integer(total_count),
    do: page * per_page >= total_count

  defp complete?(_page, _per_page, _item_count, _total_count), do: false
end
