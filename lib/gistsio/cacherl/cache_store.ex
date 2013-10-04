defmodule Cacherl.Store do
	@table __MODULE__

	def init do
		:ets.new(@table, [:public, :named_table])
		:ok
	end
	
	def insert(key, pid) do
		:ets.insert(@table, {key, pid})
	end

	def lookup(key) do
		case :ets.lookup(@table, key) do
			[{^key, pid}] -> {:ok, pid}
			[] -> {:error, :not_found}
		end
	end

	def match(matcher) do
		:ets.match(@table, matcher)
	end

	def delete(pid) do
		:ets.match_delete(@table, {:'_', pid})
	end
end