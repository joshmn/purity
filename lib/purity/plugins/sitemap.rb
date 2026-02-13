hook :after_build do |config, dest|
  next unless config["url"]

  url = config["url"].chomp("/")
  pages = config["data"]["pages"]

  doc = REXML::Document.new
  doc << REXML::XMLDecl.new("1.0", "UTF-8")
  urlset = doc.add_element("urlset", "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9")
  pages.each do |page|
    urlset.add_element("url").add_element("loc").add_text("#{url}#{page["url"]}")
  end

  out = +""
  doc.write(out, 2)
  File.write(File.join(dest, "sitemap.xml"), out << "\n")
  puts("  sitemap.xml")
end
