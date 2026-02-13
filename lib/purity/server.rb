# frozen_string_literal: true

module Purity

  module Server
    def serve(port: 4567)
      build
      server = make_server(port: port)
      puts("serving at http://localhost:#{port}")
      trap("INT") { server.shutdown }
      server.start
    end

    def watch(port: 4567)
      @livereload = true
      build
      @build_time = Time.now.to_i
      server = make_server(port: port)
      server.mount_proc("/__livereload") do |_, res|
        res.content_type = "text/plain"
        res.body = @build_time.to_s
      end
      puts("watching #{src}/ and serving at http://localhost:#{port}")
      start_watcher
      trap("INT") { server.shutdown }
      server.start
    end

    private

    def make_server(port:)
      dest_dir = dest
      server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
      server.mount_proc("/") do |req, res|
        path = req.path.chomp("/")
        base = File.join(dest_dir, path)
        found = [base, "#{base}.html", File.join(base, "index.html")].find { |f| File.file?(f) }
        if found
          res.body = File.binread(found)
          res.content_type = WEBrick::HTTPUtils.mime_type(found, WEBrick::HTTPUtils::DefaultMimeTypes)
        else
          res.status = 404
          custom_404 = File.join(dest_dir, "404.html")
          if File.file?(custom_404)
            res.body = File.binread(custom_404)
            res.content_type = "text/html"
          else
            res.body = "not found"
          end
        end
      end
      server
    end

    def start_watcher
      mtimes = {}
      Dir.glob(File.join(src, "**/*")).select { |f| File.file?(f) }.each { |f| mtimes[f] = File.mtime(f) }
      Thread.new do
        loop do
          sleep(1)
          changed = false
          Dir.glob(File.join(src, "**/*")).select { |f| File.file?(f) }.each do |f|
            mt = File.mtime(f)
            if mtimes[f] != mt
              mtimes[f] = mt
              changed = true
            end
          end
          if changed
            puts("rebuilding...")
            build
            @build_time = Time.now.to_i
          end
        end
      end
    end

    def inject_livereload(html:)
      script = "<script>(function(){var t;setInterval(function(){fetch('/__livereload').then(function(r){return r.text()}).then(function(s){if(t&&s!==t)location.reload();t=s})},1000)})()</script>"
      html.sub("</body>", "#{script}\n</body>")
    end
  end
end
