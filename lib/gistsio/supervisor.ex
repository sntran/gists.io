defmodule GistsIO.Supervisor do
    use Supervisor.Behaviour

    def start_link do
        :supervisor.start_link(__MODULE__, [])
    end

    def init([]) do
        client_id = :application.get_env(:gistsio, :client_id, "")
        client_secret = :application.get_env(:gistsio, :client_secret, "")

        children = [
            worker(Session, []),
            supervisor(GistsIO.GistClientManager, [client_id, client_secret])
        ]

        supervise(children, strategy: :one_for_one)
    end
end
