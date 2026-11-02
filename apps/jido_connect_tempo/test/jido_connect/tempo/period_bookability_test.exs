defmodule Jido.Connect.Tempo.PeriodBookabilityTest do
  use ExUnit.Case, async: true

  # `build/4` with the recorded periods of August 15 to October 15, 2026
  # and a reader that reports each approval read and answers with an OPEN
  # approval of that period.

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.{PeriodBookability, TimesheetApproval}

  @attrs %{
    account_id: "account-2",
    from: "2026-08-15",
    to: "2026-10-15",
    checked_at: "2026-11-02T12:00:00Z"
  }
  @periods [
    %{from: "2026-08-01", to: "2026-08-31"},
    %{from: "2026-09-01", to: "2026-09-30"},
    %{from: "2026-10-01", to: "2026-10-31"}
  ]

  describe ":max_periods" do
    test "a host may raise or lower the bound; exactly that many periods are read" do
      assert {:ok, %PeriodBookability{segments: [_, _, _]}} =
               PeriodBookability.build(@attrs, @periods, reader(), max_periods: 3)

      assert reads() == ["2026-08-01", "2026-09-01", "2026-10-01"]

      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :period_limit_exceeded,
                details: %{max_periods: 2}
              }} = PeriodBookability.build(@attrs, @periods, reader(), max_periods: 2)

      assert reads() == []
    end

    test "only periods that intersect the range count" do
      periods = [%{from: "2026-07-01", to: "2026-07-31"} | @periods]

      assert {:ok, %PeriodBookability{segments: [_, _, _]}} =
               PeriodBookability.build(@attrs, periods, reader(), max_periods: 3)

      assert reads() == ["2026-08-01", "2026-09-01", "2026-10-01"]
    end

    test "an invalid bound fails before any approval read" do
      for value <- [0, -1, 1.5, "20", nil] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_bookability_option,
                  subject: :max_periods
                }} = PeriodBookability.build(@attrs, @periods, reader(), max_periods: value)
      end

      assert reads() == []
    end
  end

  defp reader do
    test_pid = self()

    fn %{from: from, to: to} ->
      send(test_pid, {:read, from})

      {:ok,
       %TimesheetApproval{
         period_from: from,
         period_to: to,
         user_account_id: @attrs.account_id,
         status: "OPEN",
         updated_at: nil
       }}
    end
  end

  defp reads(acc \\ []) do
    receive do
      {:read, from} -> reads([from | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
