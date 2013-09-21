defmodule GistsIO do
    use Application.Behaviour

    # See http://elixir-lang.org/docs/stable/Application.Behaviour.html
    # for more information on OTP Applications
    def start(_type, _args) do
        port = 8080
        dispatch = :cowboy_router.compile([
                                 {:_, [
                                    {"/:gist", GistsIO.GistsListHandler, []}
                                 ]}
                             ])
        {:ok, _} = :cowboy.start_http(:http, 100,
                                    [port: port],
                                    [env: [dispatch: dispatch]])
        GistsIO.Supervisor.start_link
    end
end
