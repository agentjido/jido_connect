defmodule Jido.Connect.Tempo.Input.DateRange do
  @moduledoc false

  # The inclusive booking-day range of a Tempo read. `from` and `to` are ISO
  # dates in the form YYYY-MM-DD, and `from` is not after `to`. The handler
  # checks the range before it resolves the provider client, and the client
  # checks it before any request, so an injected client never sees an invalid
  # range and the rule exists once.

  alias Jido.Connect.Error

  @type t :: %{from: String.t(), to: String.t(), first: Date.t(), last: Date.t()}

  @spec parse(term(), term()) :: {:ok, t()} | {:error, Error.ValidationError.t()}
  def parse(from, to) do
    with {:ok, first} <- date(from, :from),
         {:ok, last} <- date(to, :to) do
      if Date.compare(first, last) == :gt do
        invalid(:to, "must not be before from")
      else
        {:ok, %{from: from, to: to, first: first, last: last}}
      end
    end
  end

  # Also the date rule of a worklog's booking day. Date.from_iso8601/1 alone
  # would also accept forms such as +2026-10-01.
  @spec iso_date(term()) :: {:ok, Date.t()} | :error
  def iso_date(value) do
    with true <- is_binary(value) and Regex.match?(~r/\A\d{4}-\d{2}-\d{2}\z/, value),
         {:ok, date} <- Date.from_iso8601(value) do
      {:ok, date}
    else
      _invalid -> :error
    end
  end

  defp date(value, field) do
    case iso_date(value) do
      {:ok, date} -> {:ok, date}
      :error -> invalid(field, "must be an ISO date such as 2026-10-01")
    end
  end

  defp invalid(field, message) do
    {:error,
     Error.validation("Invalid Tempo date range",
       reason: :invalid_date_range,
       subject: field,
       details: %{field: field, message: message}
     )}
  end
end
