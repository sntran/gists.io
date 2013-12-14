defmodule GistsIO.FileHandler do
	alias :cowboy_req, as: Req
	alias GistsIO.Utils
	alias GistsIO.Cache

	def init(_transport, _req, []) do
		{:upgrade, :protocol, :cowboy_rest}
	end

	def allowed_methods(req, state) do
		{["GET"], req, state}
	end

	def content_types_provided(req, state) do
		{[
			{content_type(req), :get_image}
		], req, state}
	end

	defp content_type(req) do
		{filename, req} = Req.binding :filename, req
		case filename do
			:undefined -> {"application", "octet-stream", []}
			_ -> case :filename.extension(filename) do
				"" -> {"application", "octet-stream", []}
				".gif" -> {"image", "gif", []}
				".png" -> {"image", "png", []}
				".jpeg" -> {"image", "jpeg", []}
				".jpg" -> {"image", "jpeg", []}
				".svg" -> {"image", "svg+xml", []}
			end
		end
	end

	def resource_exists(req, _state) do
		case Req.binding :gist, req do
			{:undefined, req} -> {:false, req, :index}
			{gist_id, req} when is_integer(gist_id) ->
				maybe_get_gist(req, gist_id)
		end
	end

	defp maybe_get_gist(req, gist_id) do
		gist_id = :erlang.integer_to_binary(gist_id) 
		client = Session.get("gist_client", req)
		case Cache.get_gist gist_id, client do
			{:error, _} -> {:false, req, gist_id}
			{:ok, gist} -> maybe_get_file(req, gist)
		end
	end

	defp maybe_get_file(req, gist) do
		gist_id = gist["id"]
		username = username = gist["user"]["login"]
		case Req.binding :filename, req do
			{:undefined, req} ->
				{:false, req, {:redirect, "/#{username}/#{gist_id}"}}
			{filename, req} ->
				file = gist["files"][filename]
				timestamp = Cache.gist_last_updated(username, gist_id)
				{file !== nil, req, {file, timestamp}}
		end
	end

	def previously_existed(req, {:redirect, path}) do
		{:true, req, {:redirect, path}}
	end

	def previously_existed(req, state) do
		{:false, req, state}
	end

	def moved_permanently(req, {:redirect, path}) do
		{{:true, path}, req, path}
	end

	def generate_etag(req, state) do
		{{:strong, :base64.encode(:crypto.md5(term_to_binary(state)))}, req, state}
	end
	
	def last_modified(req, {file, timestamp}) do
		time = :calendar.gregorian_seconds_to_datetime(timestamp)
		{time, req, {file, timestamp}}
	end

	def get_image(req, {file, timestamp}) do
		content = file["content"]
		content = Regex.replace(%r/^data:image\/[^;]*;base64,/, content, "")
					|> :base64.mime_decode
		{content, req, {file, timestamp}}
	end

	# def expires(req, state) do
	# 	{{{2021, 1, 1}, {0, 0, 0}}, req, state}
	# end
	
end