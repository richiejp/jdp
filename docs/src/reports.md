# Static Reports

This instance of JDP has been configured to generate some static reports at
the same time as the documentation. These are listed below.

# External HTML Reports

These reports were generated directly as HTML, so we generate some links to
them using the code displayed.

```@example html-list
using Markdown

html_report_paths = filter(readdir("reports")) do entry
	endswith(entry, ".html") && 
	isfile("reports/$entry") &&
	entry != "index.html"
end

join(map(html_report_paths) do path
	"* [$(path[1:end-5])](reports/$path)"
end, "\n") |> Markdown.parse
```

# Markdown

The following reports were generated as Markdown or plain text which is the
preferred format of
[Documenter.jl](https://juliadocs.github.io/Documenter.jl/stable/). So we can
include them inline, although they probably won't be displayed exactly as
intended or indexed correctly.

## Raw links

The following code will create links to the raw Markdown report texts.

```@example markdown-reports
using Markdown

md_report_paths = filter(readdir("reports")) do entry
	endswith(entry, ".md") && 
	isfile("reports/$entry")
end

links = join(map(md_report_paths) do path
	"* [$(path[1:end-3])]($path)"
end, "\n")

Markdown.parse(links)
```

## Rendered Inline

This will try to render the Markdown inline. Everything below the code is the
content of the reports.

```@example markdown-reports
inline = join(map(md_report_paths) do path
	"""# [$(path[1:end-3])]($path)
	---
	
	$(read("reports/$path", String))
	"""
end, "\n")

Markdown.parse(inline)
```
