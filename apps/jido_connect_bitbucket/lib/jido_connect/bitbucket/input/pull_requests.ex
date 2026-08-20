defmodule Jido.Connect.Bitbucket.Input.PullRequests do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Bitbucket.PullRequestContract, as: Contract

  @slug_pattern Contract.slug_pattern()
  @slug_regex Contract.slug_regex()
  @states Contract.states()
  @default_state Contract.default_state()
  @default_limit Contract.default_limit()
  @minimum_limit Contract.minimum_limit()
  @maximum_limit Contract.maximum_limit()
  @default_page Contract.default_page()
  @maximum_page Contract.maximum_page()

  def validate(input) when is_map(input) do
    normalized = %{
      workspace: Map.get(input, :workspace),
      repository: Map.get(input, :repository),
      state: Map.get(input, :state, @default_state),
      limit: Map.get(input, :limit, @default_limit),
      page: Map.get(input, :page, @default_page)
    }

    with :ok <- validate_slug(:workspace, normalized.workspace),
         :ok <- validate_slug(:repository, normalized.repository),
         :ok <- validate_state(normalized.state),
         :ok <- validate_integer(:limit, normalized.limit, @minimum_limit, @maximum_limit),
         :ok <- validate_integer(:page, normalized.page, @default_page, @maximum_page) do
      {:ok, normalized}
    end
  end

  def validate(_input), do: invalid_input(:input, "input must be a map")

  defp validate_slug(_field, value)
       when is_binary(value) and byte_size(value) in 1..255 do
    if Regex.match?(@slug_regex, value), do: :ok, else: invalid_slug(value)
  end

  defp validate_slug(_field, value), do: invalid_slug(value)

  defp validate_state(state) when state in @states, do: :ok
  defp validate_state(_state), do: invalid_input(:state, "state is not supported")

  defp validate_integer(_field, value, minimum, maximum)
       when is_integer(value) and value >= minimum and value <= maximum,
       do: :ok

  defp validate_integer(field, _value, _minimum, _maximum),
    do: invalid_input(field, "value is outside the allowed range")

  defp invalid_slug(value) do
    {:error,
     Error.validation("Invalid Bitbucket slug",
       reason: :invalid_bitbucket_slug,
       subject: value,
       details: %{pattern: @slug_pattern}
     )}
  end

  defp invalid_input(field, message) do
    {:error,
     Error.validation("Invalid Bitbucket pull-request input",
       reason: :invalid_bitbucket_input,
       subject: field,
       details: %{field: field, message: message}
     )}
  end
end
