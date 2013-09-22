defmodule GistsIO.GistClient do
  alias HTTPotion.Response

  def fetch_gists(user, params // []) when is_binary(user) do
    url("users/#{user}/gists", params) |> fetch
  end
  
  def fetch_gist(id) when is_integer(id) do
    url("gists/#{id}", []) |> fetch
  end

  def fetch_gist(id) do
    { :error, "invalid gist id" }
  end

  def fetch_comments(id) do
    url = url("gists/#{id}/comments", [])
    fetch(url)
  end
  
  def render(markdown) do
    body = Jsonex.encode([{"text", markdown}, {"mode", "gfm"}])
    url = url("markdown", [])

    HTTPotion.start
    case HTTPotion.post(url, body) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        { :ok, body }
      Response[body: _body, status_code: status, headers: _headers] ->
        { :error, "cannot render" }
    end
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

  defp url(endpoint, params) do
    clientid = "xxx"
    clientsecret = "xxx"
    url = "https://api.github.com/#{endpoint}?client_id=#{clientid}&client_secret=#{clientsecret}&"
    url <> append_query(params)
  end

  defp append_query(params) do
    Enum.map_join(params, "&", fn({k,v}) -> "#{k}=#{v}" end)
  end

end