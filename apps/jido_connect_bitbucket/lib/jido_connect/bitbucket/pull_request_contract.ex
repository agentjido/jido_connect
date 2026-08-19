defmodule Jido.Connect.Bitbucket.PullRequestContract do
  @moduledoc false

  @slug_source "[A-Za-z0-9._-]+"
  @slug_pattern "^" <> @slug_source <> "$"
  @slug_regex Regex.compile!("\\A" <> @slug_source <> "\\z")
  @states ["open", "merged", "declined", "superseded"]
  @default_state "open"
  @default_limit 20
  @minimum_limit 1
  @maximum_limit 50
  @default_page 1
  @maximum_page 10_000

  def slug_pattern, do: @slug_pattern
  def slug_regex, do: @slug_regex
  def states, do: @states
  def response_states, do: Enum.map(@states, &String.upcase/1)
  def default_state, do: @default_state
  def default_limit, do: @default_limit
  def minimum_limit, do: @minimum_limit
  def maximum_limit, do: @maximum_limit
  def default_page, do: @default_page
  def maximum_page, do: @maximum_page
end
