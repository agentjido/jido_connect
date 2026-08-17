defmodule Jido.Connect.Provider.Transport do
  @moduledoc """
  Provider-neutral HTTP transport helpers for connector clients.

  Provider packages own endpoint paths, query/body construction, success
  response normalization, and provider-specific API error semantics. This
  module only standardizes request construction and Req execution boundaries.
  """

  alias Jido.Connect.Http

  @type method :: :get | :post | :put | :patch | :delete

  @spec bearer_request(String.t(), String.t(), keyword()) :: Req.Request.t()
  def bearer_request(base_url, access_token, opts \\ [])
      when is_binary(base_url) and is_binary(access_token) do
    Http.bearer_request(base_url, access_token, opts)
  end

  @spec basic_request(String.t(), String.t(), String.t(), keyword()) :: Req.Request.t()
  def basic_request(base_url, username, password, opts \\ [])
      when is_binary(base_url) and is_binary(username) and is_binary(password) do
    Http.basic_request(base_url, username, password, opts)
  end

  @spec request(Req.Request.t(), method(), keyword()) :: term()
  def request(%Req.Request{} = request, :get, opts), do: Req.get(request, opts)
  def request(%Req.Request{} = request, :post, opts), do: Req.post(request, opts)
  def request(%Req.Request{} = request, :put, opts), do: Req.put(request, opts)
  def request(%Req.Request{} = request, :patch, opts), do: Req.patch(request, opts)
  def request(%Req.Request{} = request, :delete, opts), do: Req.delete(request, opts)

  @spec provider_error(term(), keyword()) :: {:error, Jido.Connect.Error.ProviderError.t()}
  def provider_error(response, opts), do: Http.provider_error(response, opts)
end
