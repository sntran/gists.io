gists.io
========

Gist-based blogging platform in Elixir

## Installation

* Install `elixir` and `rebar`
* `mix deps.get --all`
* `mix run --no-halt`
* Open your browser on port `8080`

## Endpoints

* `/:username`: Listing all gists of the user `username`
* `/:username/:gistid`: Display the gist `gistid` of the user `username`
* `/:gistid` when `gistid`: Display the gist `gistid`

## Conventions

* Only gist with Markdown file will be displayed.
* Only support one Markdown file per gist.
* Gist's description is used for title and teaser, in which the first line is title, and the rest is teaser.

## Changelog

### v0.0.1

* Display all gists of specific user
* Display gist by id
* Display gist of a user
* Use the first Markdown file as blog entry
* List other files as attachment
* First line of description is entry's title
* The rest of description is entry's teaser
* Embed inline other files using `<%= files[filename] %>`
