defmodule GistsIO.GistsListHandler do
	alias :cowboy_req, as: Req

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
		case Req.binding :gist, req do
			{:undefined, req} -> {:false, req, :index}
			{gistId, req} -> 
				gist = GistFetcher.parse_gist gistId
				files = gist["files"]
				isMarkdown = fn({name, attrs}) -> 
					attrs["language"] === "Markdown" 
				end
				
				if Files !== nil and Enum.any?(files, isMarkdown) do
					{:true, req, gist}
				else
					{:false, req, gist}
				end
		end
	end

	def page_json(req, gist) do
		{Jsonex.encode(gist), req, gist}
	end
end