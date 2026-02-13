# Purity

A good-enough static site generator in ~500 lines of Ruby. ERB templates, layouts, partials, markdown, data files, collections, plugins, and a dev server with live reload. No asset pipeline, no build step beyond "turn templates into HTML files."

Its only runtime dependency is `webrick`. Markdown support works via a plugin hook—bring your own gem (`kramdown`, `redcarpet`, whatever) and write a three-line plugin.

If your site is HTML and you want a tool that does exactly what a static site generator should do and absolutely nothing else, this is it.

## Install

```
gem install purity
```

Or add it to your Gemfile:

```ruby
gem "purity"
```

## Quick start

```
purity new mysite
cd mysite
purity watch
```

That scaffolds a working site under `mysite/src/`, builds it to `mysite/build/`, starts a dev server at `localhost:4567`, and rebuilds when you change a file.

Or do it manually:

```
mkdir -p src
```

Create a layout at `src/_layout.html`:

```html
<!doctype html>
<html>
<head><title><%= page.title %></title></head>
<body><%= page.content %></body>
</html>
```

Create a page at `src/index.html`:

```html
—-
title: Home
—-
<h1><%= page.title %></h1>
```

Run `purity`. Your site is in `build/`.

## Project structure

```
src/
  _site.yml          # site-wide config (optional)
  _layout.html       # default layout
  _header.html       # partial (any file starting with _)
  _data/             # YAML/JSON data files (optional)
    nav.yml
    social.json
  _helpers/          # template helper methods (optional)
    formatting.rb
  _plugins/          # Ruby plugins (optional)
    analytics.rb
  index.html         # page
  about.html         # page
  posts/             # collection directory
    first-post.html
    second-post.md
  css/
    style.css        # copied as-is to build/css/style.css
```

Files and directories starting with `_` are special: layouts, partials, config, data, helpers, plugins. Everything else is either a page (`.html`, `.md`) or an asset (copied as-is). Output goes to `build/` by default.

## Templates

Templates are rendered via ERB. You get the full power of Ruby. Pages that are `.html` get the full ERB treatment. `.md` files work the same way—add a plugin hook for your preferred markdown gem.

### Variable namespaces

Every template has three namespaced objects:

`site` wraps `_site.yml` config + computed values:

```html
<%= site.site_name %>
<%= site.url %>
<%= site.env %>
```

`page` wraps current page front matter + computed values:

```html
<%= page.title %>
<%= page.url %>
<%= page.excerpt %>
<%= page.content %>  <%# in layouts, the rendered page body %>
```

`data` the data store, including data files and collections:

```html
<%= data.nav %>       <%# from _data/nav.yml %>
<%= data.posts %>     <%# configured collection %>
<%= data.pages %>     <%# all non-standalone, non-draft pages %>
```

All objects support both dot access and bracket access:

```html
<%= page.title %>
<%= page["title"] %>
<%= site["site_name"] %>
```

Undefined variables render as empty strings (no errors) unless strict mode is enabled.

### Conditionals

```html
<% if page.show_nav %>
  <nav>...</nav>
<% end %>

<% if page.theme == "dark" %>
  <link rel="stylesheet" href="/dark.css">
<% end %>

<% if page.logged_in %>
  <p>Welcome back</p>
<% else %>
  <p>Please log in</p>
<% end %>

<% unless page.hide_footer %>
  <footer>...</footer>
<% end %>
```

### Loops

```html
<% data.posts.each do |post| %>
  <article>
    <h2><%= post.title %></h2>
    <time><%= post.date %></time>
  </article>
<% end %>
```

Standard Ruby iteration. Collection items support both dot and bracket access.

### Partials

```erb
<%= partial "_header.html" %>
<%= partial "_card.html", title: "About", link: "/about/" %>
```

Partials receive the current template context plus any keyword arguments merged into the page hash. Arguments are scoped to the partial and don't leak into the parent. Partials can include other partials. A missing partial renders as an empty string.

### content_for blocks

Pages can inject content into specific spots in the layout:

```html
—-
title: Contact
—-
<% content_for :head do %>
  <link rel="stylesheet" href="/contact.css">
<% end %>

<% content_for :scripts do %>
  <script src="/contact.js"></script>
<% end %>

<h1>Contact us</h1>
```

The layout yields those blocks wherever you want them:

```html
<head>
  <title><%= page.title %></title>
  <%= content_for :head %>
</head>
<body>
  <%= page.content %>
  <%= content_for :scripts %>
</body>
```

You can check if a block was provided with `content_for?(:head)`.

## Front matter

Every page can start with YAML front matter between ` -` fences:

```yaml
—-
title: My Page
description: A page about things
—-
```

### Reserved keys

| Key | Effect |
|—-|—-|
| `layout` | Layout file to use, minus the leading `_` and `.html`. Default: `layout` (uses `_layout.html`) |
| `layout: false` | Output the page as-is with no layout wrapping |
| `draft: true` | Exclude from build unless ` drafts` is passed |
| `date` | Any `YYYY-MM-DD`. Used for feed generation |
| `permalink` | Custom output path. `/blog/my-post/` writes to `build/blog/my-post/index.html` |
| `excerpt` | Custom excerpt. Overrides auto-extraction |

Everything else becomes available as `page.<key>` in templates.

## Layouts

The default layout is `_layout.html`. A minimal one:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title><%= page.title %></title>
  <%= content_for :head %>
</head>
<body>
  <%= page.content %>
  <%= content_for :scripts %>
</body>
</html>
```

`<%= page.content %>` is where the page body goes.

### Nested layouts

A layout can specify its own parent:

```html
—-
layout: base
—-
<article class="post">
  <%= page.content %>
</article>
```

This wraps its content in `<article>`, then gets wrapped by `_base.html`. The chain continues as long as layouts reference parents.

## Site config

`src/_site.yml` sets site-wide variables and build options:

```yaml
url: https://example.com
site_name: My Site
description: A site about things
dest: public
```

| Key | Effect |
|—-|—-|
| `url` | Enables sitemap.xml and feed.xml generation |
| `site_name` | Used in the RSS feed title |
| `description` | Used in the RSS feed description |
| `dest` | Output directory. Default: `build` |
| `clean_urls` | Rewrite `about.html` to `about/index.html`. Default: `true` |
| `strict_variables` | Raise on undefined variable access. Default: `false` |
| `collections` | Directory-based collection config |
| `environments` | Per-environment config overrides |

Config values are available as `site.<key>` in templates. `page.<key>` accesses front matter.

## Collections

Configure directory-based collections in `_site.yml`:

```yaml
collections:
  posts:
    sort_by: date
    order: desc
  projects:
    sort_by: title
```

Pages under `src/posts/` belong to the `posts` collection. Pages under `src/projects/` belong to `projects`. A page is matched by its first path segment matching a configured collection name.

Access collections through `data`:

```html
<% data.posts.each do |post| %>
  <article>
    <h2><a href="<%= post.url %>"><%= post.title %></a></h2>
    <time><%= post.date %></time>
    <p><%= post.excerpt %></p>
  </article>
<% end %>
```

Each collection item has all its front matter keys plus `url` (the clean URL path) and `excerpt`.

### `data.pages`

`data.pages` is a built-in collection of all non-standalone, non-draft pages (regardless of whether they're in a configured collection):

```html
<nav>
  <% data.pages.each do |p| %>
    <a href="<%= p.url %>"><%= p.title %></a>
  <% end %>
</nav>
```

## Clean URLs

By default, Purity rewrites output paths so URLs don't need `.html` extensions:

- `about.html` builds to `about/index.html` (served as `/about/`)
- `blog/post.html` builds to `blog/post/index.html` (served as `/blog/post/`)
- `index.html` stays as `index.html` (served as `/`)
- `404.html` stays as `404.html` (used by the dev server for custom 404 pages)

Disable with `clean_urls: false` in `_site.yml`. Permalink pages are unaffected—they always use whatever path you set.

## Environment

`site.env` is available in every template. The CLI sets defaults automatically:

- `purity serve` / `purity watch`: defaults to `development`
- `purity` (bare build): defaults to `production`

Set `PURITY_ENV` yourself to override:

```
PURITY_ENV=staging purity
```

Use it in templates:

```html
<% if site.env == "production" %>
  <script src="/analytics.js"></script>
<% end %>
```

### Per-environment config

Override any config value per environment:

```yaml
url: https://example.com
site_name: My Site

environments:
  development:
    strict_variables: true
  production:
    strict_variables: false
```

The env-specific hash merges into top-level config. The `environments` key itself doesn't leak as a template variable.

## Strict mode

Set `strict_variables: true` in `_site.yml` (or per-environment) to make undefined variable access raise `Purity::UndefinedVariableError` instead of returning nil:

```yaml
strict_variables: true
```

Useful during development to catch typos in template variable names.

## Page context

Every template has access to `page.url`, the URL path of the page being rendered:

```html
<nav>
  <a href="/" class="<%= page.url == "/" ? "active" : "" %>">Home</a>
  <a href="/about/" class="<%= page.url == "/about/" ? "active" : "" %>">About</a>
</nav>
```

Values look like `/`, `/about/`, `/blog/my-post/`. Root index is `/`.

## Excerpts

Every page gets an `excerpt`. Three ways it's determined, in priority order:

1. `excerpt:` in front matter—always wins
2. `<!— more —>` separator in the body—everything before it becomes the excerpt
3. First paragraph—the text before the first blank line

Excerpts are extracted from the raw body before ERB processing. The `<!— more —>` marker is an HTML comment, so it's invisible in browsers when the full post renders.

## OG meta fallbacks

`page.og_title` falls back to `page.title` and `page.og_description` falls back to `page.description` if not explicitly set. Use them in your layout:

```html
<meta property="og:title" content="<%= page.og_title %>">
<meta property="og:description" content="<%= page.og_description %>">
```

## Data files

Put YAML or JSON files in `src/_data/` and access them through the `data` variable:

```yaml
# src/_data/nav.yml
- label: Home
  url: /
- label: About
  url: /about/
```

```html
<% data.nav.each do |item| %>
  <a href="<%= item.url %>"><%= item.label %></a>
<% end %>
```

Nested directories use dot notation: `src/_data/i18n/en.yml` is accessed as `data["i18n.en"]`. JSON works the same way—`src/_data/social.json` is `data.social`.

Data files are cached after first access. Supports `.yml`, `.yaml`, and `.json`.

## Markdown

Purity doesn't ship a markdown renderer. Pages with a `.md` extension get `meta["format"]` set to `"md"` a plugin checks that and converts however it wants. Bring your own gem and hook it in.

Create `src/_plugins/markdown.rb`:

```ruby
require "kramdown"

hook(:before_layout) do |content, meta, context|
  next content unless meta["format"] == "md"
  Kramdown::Document.new(content).to_html
end
```

Or if you prefer redcarpet:

```ruby
require "redcarpet"

engine = Redcarpet::Markdown.new(
  Redcarpet::Render::HTML,
  fenced_code_blocks: true, tables: true, autolink: true
)

hook(:before_layout) do |content, meta, context|
  next content unless meta["format"] == "md"
  engine.render(content)
end
```

The rendering order is ERB first, then `before_layout` hooks (where markdown conversion happens), then layout wrapping. This means ERB expressions resolve before the markdown processor sees the document, so variables, loops, and partials all work as expected inside `.md` files.

`.md` files output as `.html` `src/blog/post.md` builds to `build/blog/post.html`.

Without a markdown plugin, `.md` files pass through as raw text.

## Helpers

Drop Ruby files in `src/_helpers/` with plain method definitions. Every method becomes available in your templates, layouts, and partials.

```ruby
# src/_helpers/formatting.rb
def reading_time(text)
  words = text.split.size
  "#{(words / 200.0).ceil} min read"
end

def format_date(date)
  date.strftime("%B %d, %Y")
end
```

Use them in any template:

```html
<time><%= format_date(page.date) %></time>
```

Helpers can call built-in methods like `partial`, `content_for`, and `content_for?` since they share the same render context. Multiple helper files are loaded alphabetically and all methods are available everywhere.

Helpers are for template methods. For build pipeline hooks (transforming content, injecting variables, post-processing HTML), use [plugins](#plugins).

## Plugins

Drop Ruby files in `src/_plugins/`. They're evaluated in the site's context, so you have access to `hook`:

```ruby
hook(:before_render) do |context, relative_path|
  context[:page]["year"] = Time.now.year.to_s
end
```

### Available hooks

`after_parse` After all pages are parsed, before any rendering. Gets the site config hash and the array of parsed pages `[rel, meta, body]`.

```ruby
hook(:after_parse) do |config, pages|
  pages.reject! { |rel, meta, _| meta["title"]&.start_with?("Draft") }
end
```

`before_render` Before each page renders. Gets the structured context hash `{ site:, page:, data: }` and the page's relative path. Modify the context to inject variables.

```ruby
hook(:before_render) do |context, relative_path|
  context[:page]["build_time"] = Time.now.to_s
end
```

`before_layout` After ERB renders the page body but before the layout wraps it. Gets the rendered content string, the page's meta hash, and the structured context hash. Must return the (possibly modified) content. This is where markdown conversion belongs.

```ruby
hook(:before_layout) do |content, meta, context|
  next content unless meta["format"] == "md"
  Kramdown::Document.new(content).to_html
end
```

`after_render` After each page renders. Gets the final HTML string, the structured context, and relative path. Must return the (possibly modified) HTML.

```ruby
hook(:after_render) do |html, context, relative_path|
  html.gsub("PLACEHOLDER", context[:site]["site_name"])
end
```

`after_build` After the entire build completes. Gets the site config hash and the output directory path.

```ruby
hook(:after_build) do |config, dest_path|
  system("npx tailwindcss -i src/input.css -o #{dest_path}/css/style.css —minify")
end
```

## CLI

```
purity new <dir>        # scaffold a new site
purity                  # build the site
purity serve [port]     # build and serve (default: 4567)
purity watch [port]     # build, serve, rebuild on file changes
purity help             # show help
purity version          # show version
```

`watch` includes live reload—the browser refreshes automatically when you save a file.

Pass ` drafts` to include pages with `draft: true`.

The dev server serves `build/404.html` with a 404 status when a page isn't found, so your custom 404 page works during development. If no `404.html` exists, it returns plain text.

## Generated files

When `url` is set in `_site.yml`, Purity generates:

- `sitemap.xml` All pages except standalone (`layout: false`) and drafts
- `feed.xml` RSS 2.0 feed of the 20 most recent pages with a `date` in their front matter (across all collections)

## What this doesn't do

No Sass/LESS. No image optimization. No JavaScript bundling. No pagination. No i18n.

If you need those things, use [Jekyll](https://jekyllrb.com/), [Hugo](https://gohugo.io/), or [Bridgetown](https://www.bridgetownrb.com/). Purity exists for sites where the complexity of those tools exceeds the complexity of the site itself.

## License

MIT
