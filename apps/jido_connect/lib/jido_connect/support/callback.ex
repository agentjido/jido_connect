defmodule Jido.Connect.Callback do
  @moduledoc false

  alias Jido.Connect.{Error, SafeStacktrace}

  @spec call(module(), atom(), [term()], keyword()) :: {:ok, term()} | {:error, Error.error()}
  def call(module, function, args, opts \\ [])
      when is_atom(module) and is_atom(function) and is_list(args) do
    run(fn -> apply(module, function, args) end,
      phase: Keyword.get(opts, :phase, :callback),
      details:
        opts
        |> Keyword.get(:details, %{})
        |> Map.put_new(:module, module)
        |> Map.put_new(:function, function)
    )
  end

  @spec run((-> term()), keyword()) :: {:ok, term()} | {:error, Error.error()}
  def run(fun, opts \\ []) when is_function(fun, 0) do
    {:ok, fun.()}
  rescue
    exception ->
      {:error,
       Error.execution("Jido Connect callback raised",
         phase: Keyword.get(opts, :phase, :callback),
         details:
           opts
           |> Keyword.get(:details, %{})
           |> Map.merge(exception_details(exception, __STACKTRACE__))
       )}
  catch
    kind, reason ->
      {:error,
       Error.execution("Jido Connect callback did not return normally",
         phase: Keyword.get(opts, :phase, :callback),
         details:
           Keyword.get(opts, :details, %{})
           |> Map.merge(%{
             kind: kind,
             reason: Jido.Connect.Sanitizer.sanitize(reason, :transport)
           })
       )}
  end

  defp exception_details(exception, stacktrace) do
    %{
      exception: exception.__struct__,
      message: "Jido Connect callback raised",
      stacktrace: SafeStacktrace.format(stacktrace)
    }
  end
end
