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

### v0.3.0

* Cache system
* Pagination on the filtered blog-like gists.
* Support saving rendered Markdown to static HTML.

### v0.2.0

* Authenticate with GitHub.
* Create, edit and delete gists.
* Comment on a gist.
* Editor supports Markdown preview.

### v0.0.6

 * Pagination support (30 per page, but not filter for blog-like gists)

### v0.0.5

 * Fixed a bug when user does not have blog-like gist.
 * Added a supervisor for all gist clients.
 * Root sup to manage the `Session` and the new sup.

### v0.0.4

 * Added session support
 * ETS-based session is default.
 * Each user keeps the GIST client instance in session.

### v0.0.3

* Layout using Bootstrap 
* Styles by @kcjpop

### v0.0.2

* Login using GitHub.
* Only display public gists.

### v0.0.1

* Display all gists of specific user
* Display gist by id
* Display gist of a user
* Use the first Markdown file as blog entry
* List other files as attachment
* First line of description is entry's title
* The rest of description is entry's teaser
* Embed inline other files using `<%= files[filename] %>`
