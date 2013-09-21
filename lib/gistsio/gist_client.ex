defmodule GistsIO.GistClient do
  alias HTTPotion.Response

  def fetch_gists(user, params // []) when is_binary(user) do
    user_gists_url(user, params) |> fetch
  end
  
  def fetch_gist(id) when is_integer(id) do
    gist_url(id) |> fetch
  end

  def fetch_gist(id) do
    { :error, "invalid gist id" }
  end

  defp fetch(url) do
    HTTPotion.start
    case HTTPotion.get(url) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        { :ok, Jsonex.decode body }
      Response[body: _body, status_code: status, headers: _headers] ->
        { :error, "no gist" }
    end
  end

  defp gist_url(id) do
    "https://api.github.com/gists/#{id}"
  end

  defp user_gists_url(user, params) do
    "https://api.github.com/users/#{user}/gists?" <> append_query(params)
  end

  defp append_query([]) do
    ""
  end

  defp append_query([{key, value} | rest]) do
    "#{key}=#{value}&" <> append_query(rest)
  end
end