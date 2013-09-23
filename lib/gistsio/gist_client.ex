defmodule GistsIO.GistClient do
  alias HTTPotion.Response
  use GenServer.Behaviour

  def start_link(client_id, client_secret) do
    :gen_server.start_link({:local, GistsIO.GistClient}, GistsIO.GistClient, [client_id, client_secret], [])
  end

  # APIs
  def fetch_gists(user, params // []) when is_binary(user) do
    :gen_server.call(GistsIO.GistClient, ["gists", user | params])
  end
  
  def fetch_gist(id) when is_integer(id) do
    :gen_server.call(GistsIO.GistClient, ["gist", id])
  end

  def fetch_comments(id) do
    :gen_server.call(GistsIO.GistClient, ["comments", id])
  end

  def render(markdown) do
    :gen_server.call(GistsIO.GistClient, ["render", markdown])
  end

  def authorize(code) do
    :gen_server.cast(GistsIO.GistClient, ["authorize", code])
  end

  # Callbacks
  def init([client_id, client_secret]) do
    {:ok, [{"client_id", client_id}, {"client_secret", client_secret}]}
  end

  def handle_call(["gists", user | params], _from, state) do
    url = url("users/#{user}/gists", params ++ state)
    {:reply, Jsonex.decode(fetch(url)), state}
  end

  def handle_call(["gist", id], _from, state) do
    url = url("gists/#{id}", state)
    {:reply, Jsonex.decode(fetch(url)), state}
  end

  def handle_call(["comments", id], _from, state) do
    url = url("gists/#{id}/comments", state)
    {:reply, Jsonex.decode(fetch(url)), state}
  end
  
  def handle_call(["render", markdown], _from, state) do
    body = Jsonex.encode([{"text", markdown}, {"mode", "gfm"}])
    url = url("markdown", state)
    {:reply, post(url, body), state}
  end
  
  def handle_cast(["authorize", code | params], state) do
    body = [{"code", code} | state]
    url = "https://github.com/login/oauth/access_token?" <> append_query(body)
    state = case fetch(url, [{:Accept, "application/json"}]) do
      {:error, _error} -> state
      body -> Jsonex.decode(body) ++ state
    end
    {:noreply, state}
  end

  defp fetch(url, headers // []) do
    HTTPotion.start
    case HTTPotion.get(url, headers) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        body
      Response[body: _body, status_code: status, headers: _headers] ->
        { :error, _body }
    end
  end

  defp post(url, body) do
    HTTPotion.start
    case HTTPotion.post(url, body) do
      Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
        body
      Response[body: _body, status_code: status, headers: _headers] ->
        { :error, _body}
    end
  end

  defp url(endpoint, params) do
    "https://api.github.com/#{endpoint}?" <> append_query(params)
  end

  defp append_query(params) do
    Enum.map_join(params, "&", fn({k,v}) -> "#{k}=#{v}" end)
  end

end