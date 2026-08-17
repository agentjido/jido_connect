defmodule Jido.Connect.Things.Client.Transport do
  @moduledoc "Req transport for the reviewed Things Cloud endpoint."

  @receive_timeout 15_000

  def request(method, url, opts) do
    request_opts = [
      method: method,
      url: url,
      headers: Keyword.fetch!(opts, :headers),
      params: Keyword.get(opts, :params, []),
      receive_timeout: Keyword.get(opts, :receive_timeout, @receive_timeout),
      redirect: false,
      retry: false
    ]

    request_opts =
      if Keyword.has_key?(opts, :body) do
        Keyword.put(request_opts, :body, Keyword.fetch!(opts, :body))
      else
        request_opts
      end

    Req.request(request_opts)
  end
end
