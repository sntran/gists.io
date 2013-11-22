defmodule GistsIO do
    use Application.Behaviour
    alias :cowboy_req, as: Req
    require Lager

    # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
    # for more information on OTP Applications
    def start(_type, _args) do
        Cacherl.Store.init() # Start the store first before any incoming request.
        Lager.info("Cache storage started.")

        port = :application.get_env(:gistsio, :port, 8080)
        dispatch = [
            {:_, [
                {"/favicon.ico", :cowboy_static, {:priv_file, :gistsio, "favicon.ico"}},
                {"/login", GistsIO.AuthHandler, []},
                {"/logout", GistsIO.AuthHandler, []},
                {"/gists", GistsIO.GistsHandler, []},
                {"/:gist", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/:username/:gist/comments", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/:username/:gist/delete", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/:username", GistsIO.GistsHandler, []},
                {"/:username/:gist", [{:gist, :int}], GistsIO.GistHandler, []},
                {"/:username/:gist", GistsIO.GistHandler, []},
                {"/s/[:...]", :cowboy_static, {:priv_dir, :gistsio, "static", 
                    [{:mimetypes, :cow_mimetypes, :all}]}}
            ]}
        ] |> :cowboy_router.compile

        {:ok, _} = :cowboy.start_http(:http, 100,
            [port: port],
            [   
                env: [dispatch: dispatch],
                onrequest: &GistsIO.onrequest/1
                # onresponse: &GistsIO.page_data/4
            ]
            # [middlewares: [:cowboy_router, :auth_handler, :cowboy_handler]]
        )

        Lager.info "Gists.IO is running on port #{port}"

        GistsIO.Supervisor.start_link
    end

    def onrequest(req) do
        req = Session.new(req)
        previous_path = Session.get("current_path", req)
        {current, req} = Req.path(req)
        if previous_path != current and :binary.match(current,"/s/") == :nomatch do
            Session.set("current_path", current, req)
            Session.set("previous_path", previous_path, req)
        end
        existing = Session.get("gist_client", req)
        {:ok, client} = if existing !== :undefined and :erlang.is_process_alive(existing) do
                {:ok, existing}
            else 
                GistsIO.GistClientManager.start_client()
        end
        Session.set("gist_client", client, req)
        req
    end

    def page_data(200, _headers, _body, req) do
        req
    end
    def page_data(_, _, _, req) do req end
    
end
