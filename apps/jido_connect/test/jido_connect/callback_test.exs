defmodule Jido.Connect.CallbackTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Callback, Error}

  defmodule CrashingHandler do
    def missing_key(credentials), do: Map.fetch!(credentials, :missing_key)
    def function_clause(%{safe: true}), do: :ok
  end

  test "a missing key does not expose credentials in a public callback error" do
    secret = "callback-secret-#{System.unique_integer([:positive])}"

    assert {:error, error} =
             Callback.call(CrashingHandler, :missing_key, [%{access_token: secret}])

    assert error.details.exception == KeyError
    assert error.details.message == "Jido Connect callback raised"
    assert is_binary(error.details.stacktrace)
    assert error.details.stacktrace =~ "CrashingHandler.missing_key/1"
    refute inspect(error) =~ secret
    refute inspect(Error.to_map(error)) =~ secret
  end

  test "a function clause does not expose its argument in a public callback error" do
    secret = "callback-secret-#{System.unique_integer([:positive])}"

    assert {:error, error} =
             Callback.call(CrashingHandler, :function_clause, [%{access_token: secret}])

    assert error.details.exception == FunctionClauseError
    assert is_binary(error.details.stacktrace)
    assert error.details.stacktrace =~ "CrashingHandler.function_clause/1"
    refute inspect(error) =~ secret
    refute inspect(Error.to_map(error)) =~ secret
  end

  test "caller details cannot replace safe exception fields" do
    secret = "callback-secret-#{System.unique_integer([:positive])}"

    assert {:error, error} =
             Callback.run(fn -> raise "failed" end,
               details: %{message: secret, stacktrace: secret, exception: secret}
             )

    assert error.details.message == "Jido Connect callback raised"
    assert error.details.exception == RuntimeError
    refute inspect(Error.to_map(error)) =~ secret
  end
end
