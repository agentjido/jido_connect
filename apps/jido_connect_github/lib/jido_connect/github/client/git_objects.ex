defmodule Jido.Connect.GitHub.Client.GitObjects do
  @moduledoc "GitHub exact commit, tree, and blob read boundary."

  alias Jido.Connect.GitHub.Client.{Response, Transport}

  def get_commit(repo, ref, access_token)
      when is_binary(repo) and is_binary(ref) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{repo}/commits/#{URI.encode(ref, &URI.char_unreserved?/1)}")
    |> Response.handle_commit_response()
  end

  def get_tree(repo, sha, recursive, access_token)
      when is_binary(repo) and is_binary(sha) and is_boolean(recursive) and
             is_binary(access_token) do
    params = if recursive, do: [recursive: 1], else: []

    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{repo}/git/trees/#{sha}", params: params)
    |> Response.handle_git_tree_response()
  end

  def get_blob(repo, sha, access_token)
      when is_binary(repo) and is_binary(sha) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{repo}/git/blobs/#{sha}")
    |> Response.handle_git_blob_response()
  end
end
