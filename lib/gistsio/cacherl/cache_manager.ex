defmodule Cacherl.Manager do
	use Supervisor.Behaviour

	def start_link() do
        :supervisor.start_link({:local, __MODULE__}, __MODULE__, [])
    end

    def start_child(value, lease_time) do
        :supervisor.start_child(__MODULE__, [value, lease_time])
    end

    def init([]) do
        children = [
            worker(Cacherl.Cache, [], restart: :temporary)
        ]

        supervise(children, strategy: :simple_one_for_one)
    end
end