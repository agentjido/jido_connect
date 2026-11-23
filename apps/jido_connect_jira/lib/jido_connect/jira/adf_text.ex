defmodule Jido.Connect.Jira.ADFText do
  @moduledoc false

  alias Jido.Connect.Atlassian.ADF
  alias Jido.Connect.Error

  # Keep the surrounding issue, comment, or signal when the rich text fails.
  # The reason is a stable string for action and signal consumers.
  @spec project(term()) :: {String.t() | nil, [String.t()] | nil, String.t() | nil}
  def project(nil), do: {nil, nil, nil}
  def project(text) when is_binary(text), do: {text, [], nil}

  def project(document) do
    case ADF.project(document, on_unsupported: :degrade) do
      {:ok, %{text: text, unsupported_nodes: types}} -> {text, types, nil}
      {:error, %Error.ValidationError{reason: reason}} -> {nil, nil, Atom.to_string(reason)}
    end
  end
end
