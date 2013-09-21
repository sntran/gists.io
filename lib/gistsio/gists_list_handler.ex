defmodule GistsIO.GistsListHandler do
	def init(_transport, req, []) do
		{:upgrade, :protocol, :cowboy_rest}
	end

	def allowed_methods(req, state) do
		{["GET"], req, state}
	end

	def content_types_provided(req, state) do
		{[
			{"application/json", :page_json}
		], req, state}
	end

	def resource_exists(req, state) do
		case :cowboy_req.binding :gist, req do
			{:undefined, req} -> {:false, req, :index}
			{gist, req} -> 
				{:true, req, gist}
		end
	end

	def page_json(req, gistId) do
		gist = GistFetcher.parse_gist gistId
		{gist, req, gist}
	end
end