defmodule GistsIO.GistClientManager do
    use Supervisor.Behaviour

    def start_link(client_id, client_secret) do
        :supervisor.start_link({:local, __MODULE__}, __MODULE__, [client_id, client_secret])
    end

    def start_client(args // []) do
        :supervisor.start_child(__MODULE__, args)
    end

    def init([client_id, client_secret]) do
        children = [
            worker(GistsIO.GistClient, [client_id, client_secret], restart: :transient)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end
end
