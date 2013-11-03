defmodule GistsIO.GistClient do
    alias HTTPotion.Response
    use GenServer.Behaviour
    @max_count 100

    def start_link(client_id, client_secret) do
        :gen_server.start_link(GistsIO.GistClient, [client_id, client_secret], [])
    end

    # APIs
    def fetch_gists(client, user, params // []) when is_binary(user) do
        :gen_server.call(client, ["gists", user | params])
    end
    
    def fetch_gist(client, id) do
        :gen_server.call(client, ["gist", id])
    end

    def create_gist(client, description, files) do
        :gen_server.call(client, ["gist", description, files])
    end

    def edit_gist(client, gist_id, description, files) do
        :gen_server.call(client, ["gist", "edit", gist_id, description, files])
    end

    def delete_gist(client, gist_id) do
        :gen_server.call(client, ["gist", "delete", gist_id])
    end

    def fetch_comments(client, id) do
        :gen_server.call(client, ["comments", id])
    end

    def create_comment(client, gist_id, comment) do
        :gen_server.call(client, ["comments", gist_id, comment])
    end

    def fetch_user(client, id) do
        :gen_server.call(client, ["user", id])
    end

    def fetch_user(client) do
        :gen_server.call(client, ["user"])
    end
    
    def render(client, markdown) do
        :gen_server.call(client, ["render", markdown])
    end

    def authorize(client, code) do
        :gen_server.cast(client, ["authorize", code])
    end

    # Callbacks
    def init([client_id, client_secret]) do
        HTTPotion.start
        {:ok, [{"client_id", client_id}, {"client_secret", client_secret}]}
    end

    def handle_call(["gists", user | params], _from, state) do
        params = params ++ [{"per_page", @max_count}]
        url = url("users/#{user}/gists", params ++ state)
        {stat, data, headers} = fetch(url)
        # When there are more pages, the headers contain Link with format
        # "<h../gists?page=3>; rel=\"next\", 
        #  <h.../gists?page=6>; rel=\"last\"; 
        #  <h.../?page=1; rel=\"first\";
        #  <h.../?page=2; rel=\"prev\""
        link = Keyword.get(headers, :"Link")
        data = Jsonex.decode(data)
        ret = [{"entries", data}, {"pager", link}]
        {:reply, {stat, ret}, state}
    end

    def handle_call(["gist", id], _from, state) do
        url = url("gists/#{id}", state)
        {stat, data, _} = fetch(url)
        {:reply, {stat, Jsonex.decode(data)}, state}
    end

    def handle_call(["gist", "delete", gist_id], _from, state) do
        url = url("gists/#{gist_id}", state)
        {stat, data, _} = delete(url)
        {:reply, {stat, Jsonex.decode(data)}, state}
    end

    def handle_call(["gist", description, files], _from, state) do
        url = url("gists", state)
        body = Jsonex.encode([{"description", description}, {"public", true}, 
            {"files", files}])
        {:reply, post(url, body), state}
    end

    def handle_call(["gist", "edit", gist_id, description, files], _from, state) do
        url = url("gists/#{gist_id}", state)
        body = Jsonex.encode([{"description", description}, {"public", true},
            {"files", files}])
        {:reply, patch(url,body), state}
    end

    def handle_call(["comments", id], _from, state) do
        url = url("gists/#{id}/comments", state)
        {stat, data, _} = fetch(url)
        {:reply, {stat, Jsonex.decode(data)}, state}
    end

    def handle_call(["comments", gist_id, comment], _from, state) do
        url = url("gists/#{gist_id}/comments", state)
        body = Jsonex.encode([{"body", comment}])
        {:reply, post(url, body), state}
    end

    def handle_call(["user", id], _from, state) do
        url = url("users/#{id}", state)
        {stat, data, _} = fetch(url)
        {:reply, {stat, Jsonex.decode(data)}, state}
    end

    def handle_call(["user"], _from, state) do
        url = url("user", state)
        {stat, data, _} = fetch(url)
        {:reply, {stat, Jsonex.decode(data)}, state}
    end
    
    def handle_call(["render", markdown], _from, state) do
        body = Jsonex.encode([{"text", markdown}, {"mode", "gfm"}])
        url = url("markdown", state)
        {:reply, post(url, body), state}
    end
    
    def handle_cast(["authorize", code | _params], state) do
        body = [{"code", code} | state]
        url = "https://github.com/login/oauth/access_token?" <> append_query(body)
        state = case fetch(url, [{:Accept, "application/json"}]) do
            {:error, _error, _} -> state
            {:ok, body, _} -> ListDict.merge(state, Jsonex.decode(body))
        end
        {:noreply, state}
    end

    defp fetch(url, req_headers // []) do
        case HTTPotion.get(url, req_headers) do
            Response[body: body, status_code: status, headers: headers] when status in 200..299 ->
                status = Keyword.get(headers, :"Status")
                if status !== "200 OK" do
                    {:error, status, headers}
                else
                    {:ok, body, headers}
                end
            Response[body: body, status_code: _status, headers: headers] ->
                {:error, body, headers}
        end
    end

    defp post(url, body) do
        case HTTPotion.post(url, body, [is_ssl: true]) do
            Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
                {:ok, body}
            Response[body: body, status_code: _status, headers: _headers] ->
                {:error, body}
        end
    end

    defp patch(url, body) do
        case HTTPotion.patch(url, body, [is_ssl: true]) do
            Response[body: body, status_code: status, headers: _headers] when status in 200..299 ->
                {:ok, body}
            Response[body: body, status_code: status, headers: _headers] ->
                {:error, body}
        end
    end

    defp delete(url, headers // []) do
        case HTTPotion.delete(url, headers) do
            Response[body: body, status_code: status, headers: headers] when status in 200..299 ->
                {:ok, body, headers}
            Response[body: body, status_code: status, headers: headers] ->
                {:error, body, headers}
        end
    end

    defp url(endpoint, params) do
        "https://api.github.com/#{endpoint}?" <> append_query(params)
    end

    defp append_query(params) do
        Enum.map_join(params, "&", fn({k,v}) -> "#{k}=#{v}" end)
    end

end