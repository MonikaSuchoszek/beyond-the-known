# Jekyll 3 decides whether to copy a static file by comparing its mtime with an
# in-memory table that starts empty in every new process, so every
# `jekyll build` deleted and re-copied all ~900 MB of photos into the
# destination. Compare with the file already in the destination instead:
# StaticFile#copy_file stamps the copy with the source mtime, so an unchanged
# file matches on mtime and size and can be skipped. See speedup.md.
module Jekyll
  class StaticFile
    alias_method :__write_unconditionally, :write

    def write(dest)
      dest_path = destination(dest)
      if File.exist?(dest_path) &&
         File.mtime(dest_path).to_i == mtime &&
         File.size(dest_path) == File.size(path)
        self.class.mtimes[path] = mtime
        return false
      end

      __write_unconditionally(dest)
    end
  end
end
