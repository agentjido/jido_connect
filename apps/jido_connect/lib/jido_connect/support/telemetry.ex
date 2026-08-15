defmodule Jido.Connect.Telemetry do
  @moduledoc """
  Telemetry boundary for Jido Connect runtime execution.

  Event metadata is intentionally low-cardinality and sanitized before emission.
  Runtime code should keep rich terms internally and call this module only at
  package boundaries.
  """

  alias Jido.Connect.{Error, Sanitizer}

  @type operation :: :invoke | :poll | :prepare | :commit
  @type phase :: :start | :stop | :exception

  @spec span(operation(), map(), (-> result)) :: result when result: term()
  def span(operation, metadata, fun)
      when operation in [:invoke, :poll, :prepare, :commit] and is_function(fun, 0) do
    start_time = System.monotonic_time()

    emit(operation, :start, %{system_time: System.system_time()}, metadata)

    try do
      result = fun.()
      duration = System.monotonic_time() - start_time

      emit(operation, :stop, %{duration: duration}, Map.merge(metadata, result_metadata(result)))

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time

        emit(
          operation,
          :exception,
          %{duration: duration},
          Map.merge(metadata, exception_metadata(exception, __STACKTRACE__))
        )

        reraise exception, __STACKTRACE__
    end
  end

  @spec emit(operation(), phase(), map(), map()) :: :ok
  def emit(operation, phase, measurements, metadata)
      when operation in [:invoke, :poll, :prepare, :commit] and
             phase in [:start, :stop, :exception] do
    :telemetry.execute(
      [:jido, :connect, operation, phase],
      measurements,
      Sanitizer.sanitize(metadata, :telemetry)
    )
  end

  defp result_metadata({:ok, _value}), do: %{status: :ok}

  defp result_metadata({:error, reason}) do
    error = Error.to_map(reason)

    %{
      status: :error,
      error_type: error.type,
      error_class: error.class,
      error_reason: error.reason,
      retryable?: error.retryable?
    }
  end

  defp result_metadata(_other), do: %{status: :unknown}

  defp exception_metadata(exception, stacktrace) do
    %{
      status: :exception,
      error_type: exception.__struct__,
      error_class: :exception,
      error_reason: nil,
      retryable?: false,
      exception: Exception.message(exception),
      stacktrace: Exception.format_stacktrace(stacktrace)
    }
  end
end
