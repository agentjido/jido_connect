defmodule Jido.Connect.Google.SearchConsole.Client.Response do
  @moduledoc "Google Search Console response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.Client.Transport
  alias Jido.Connect.Google.SearchConsole.Normalizer

  def handle_site_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, sites} <-
           normalize_items(
             body,
             "siteEntry",
             &Normalizer.site/1,
             "Google Search Console site list response was invalid"
           ) do
      {:ok,
       %{
         sites: sites
       }
       |> Data.compact()}
    end
  end

  def handle_site_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Search Console site list response was invalid",
      body
    )
  end

  def handle_site_list_response(response), do: Transport.handle_error_response(response)

  def handle_site_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.site/1, "Google Search Console site response was invalid")
  end

  def handle_site_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Search Console site response was invalid", body)
  end

  def handle_site_response(response), do: Transport.handle_error_response(response)

  def handle_search_analytics_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.search_report(body) do
      {:ok, report} ->
        {:ok, report}

      {:error, _error} ->
        Transport.invalid_success_response(
          "Google Search Console search analytics response was invalid",
          body
        )
    end
  end

  def handle_search_analytics_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Search Console search analytics response was invalid",
      body
    )
  end

  def handle_search_analytics_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end
end
