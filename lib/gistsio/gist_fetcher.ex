defmodule GistFetcher do
  alias HTTPotion.Response

  def parse_gist(id) do
    case fetch_gist(id) do
      { :ok, body } -> 
        # Jsonex.decode(body)
        body
      { :error, message } -> IO.puts message
    end
  end
  
  def fetch_gist(id) when is_binary(id) do
    HTTPotion.start
    case HTTPotion.get(gist_url(id)) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        { :ok, body }
      Response[body: _body, status_code: status, headers: _headers] ->
        { :error, "no gist" }
    end
  end

  def fetch_gist(id) do
    { :error, "invalid gist id" }
  end

  defp gist_url(id) do
    "https://api.github.com/gists/#{id}"
  end
end