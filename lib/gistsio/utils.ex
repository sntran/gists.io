defmodule GistsIO.Utils do
	def is_markdown({_name, attrs}) do
		attrs["language"] === "Markdown"
	end

	def prep_gist(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		{title, teaser} = parse_description(gist)
		gist = ListDict.put(gist, "title", title)
				|> ListDict.put("teaser", teaser)
		
	end

	def parse_description(gist) do
		{_name, entry} = Enum.at gist["files"], 0
		description = gist["description"]
		{title, teaser} = if description !== :null do
			[title] = Regex.run %r/.*$/m, description
			size = Kernel.byte_size(title)
			<<title :: [size(size), binary], teaser :: binary>> = description
			{title, teaser}
		else
			{entry["filename"], ""}
		end
	end
end