defmodule Jido.Connect.Confluence.Contract do
  @moduledoc false

  @maximum_identifier_length 255
  @maximum_title_length 255
  @maximum_markdown_length 100_000
  @maximum_cursor_length 2_048
  @maximum_version_message_length 255
  @default_limit 25
  @maximum_limit 250
  @default_max_characters 20_000
  @maximum_max_characters 100_000

  def maximum_identifier_length, do: @maximum_identifier_length
  def maximum_title_length, do: @maximum_title_length
  def maximum_markdown_length, do: @maximum_markdown_length
  def maximum_cursor_length, do: @maximum_cursor_length
  def maximum_version_message_length, do: @maximum_version_message_length
  def default_limit, do: @default_limit
  def maximum_limit, do: @maximum_limit
  def default_max_characters, do: @default_max_characters
  def maximum_max_characters, do: @maximum_max_characters
end
