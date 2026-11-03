defmodule Jido.Connect.Tempo.Client.WorkAttributes do
  @moduledoc """
  Tempo work attribute reads.

  `list/2` reads every page of `GET /4/work-attributes` through
  `Jido.Connect.Tempo.Client.Pagination` and normalizes each attribute with
  `Jido.Connect.Tempo.WorkAttribute.normalize/1`. Tempo lists the site's
  attributes, not those of one project or issue.

  The read succeeds only as a whole: a failed, looping or malformed page
  fails it with the errors of the pagination, and an attribute that does not
  normalize fails it with a `Jido.Connect.Error.ProviderError` with reason
  `:invalid_work_attribute`, `delivery: :response_received` and details
  `index`, the attribute's position in the whole list, and `field`, the
  Tempo field. No part of the list is returned, so a requirement on a later
  page is never lost.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.{Pagination, Request, Response}
  alias Jido.Connect.Tempo.WorkAttribute

  @bounds [:limit, :max_pages, :max_results]

  @doc """
  Reads every work attribute of the site, in Tempo's order.

  The optional `:limit`, `:max_pages` and `:max_results` bound the read as
  `Jido.Connect.Tempo.Client.Pagination.collect/3` describes.
  """
  @spec list(Request.t(), keyword()) ::
          {:ok, [WorkAttribute.t()]}
          | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def list(%Request{} = request, opts \\ []) when is_list(opts) do
    with {:ok, results} <-
           Pagination.collect(request, "/4/work-attributes", Keyword.take(opts, @bounds)) do
      normalize(results)
    end
  end

  defp normalize(results) do
    results
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {result, index}, {:ok, attributes} ->
      case WorkAttribute.normalize(result) do
        {:ok, attribute} ->
          {:cont, {:ok, [attribute | attributes]}}

        {:error, field} ->
          {:halt,
           Response.invalid_response("Tempo work attribute was invalid", nil,
             reason: :invalid_work_attribute,
             details: %{index: index, field: field}
           )}
      end
    end)
    |> case do
      {:ok, attributes} -> {:ok, Enum.reverse(attributes)}
      error -> error
    end
  end
end
