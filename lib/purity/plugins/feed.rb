hook :after_build do |config, dest|
  next unless config["url"]

  url = config["url"].chomp("/")
  posts = config["data"]["pages"]
    .select { |p| p["date"] }
    .sort_by { |p| p["date"].to_s }
    .reverse
    .first(20)

  doc = REXML::Document.new
  doc << REXML::XMLDecl.new("1.0", "UTF-8")
  rss = doc.add_element("rss", "version" => "2.0")
  channel = rss.add_element("channel")
  channel.add_element("title").add_text(config["site_name"].to_s)
  channel.add_element("link").add_text(url)
  channel.add_element("description").add_text(config["description"].to_s)

  posts.each do |p|
    item = channel.add_element("item")
    item.add_element("title").add_text(p["title"].to_s)
    item.add_element("link").add_text("#{url}#{p["url"]}")
    item.add_element("pubDate").add_text(p["date"].to_s)
  end

  out = +""
  doc.write(out, 2)
  File.write(File.join(dest, "feed.xml"), out << "\n")
  puts("  feed.xml")
end
