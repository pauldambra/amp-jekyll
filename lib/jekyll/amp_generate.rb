require 'thread'
require 'thwait'

module Jekyll
  # Defines the base class of AMP posts
  class AmpPost < Page
    def initialize(site, base, dir, post)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'
      self.process(@name)
      self.read_yaml(File.join(base, '_layouts'), 'amp.html')
      self.content               = post.content
      self.data['body']          = (Liquid::Template.parse post.content).render site.site_payload

      # Merge all data from post so that keys from self.data have higher priority
      self.data = post.data.merge(self.data)

      # Remove non needed keys from data
      # Excerpt will cause an error if kept
      self.data.delete('excerpt')

      self.data['canonical_url'] = post.url
    end
  end
  # Generates a new AMP post for each existing post
  class AmpGenerator < Generator
    priority :low

    def generate(site)
      dir = site.config['ampdir'] || 'amp'
      thread_count = (ENV['THREADCOUNT'] || 4).to_i

      queue = Queue.new
      threads = []

      site.posts.docs
        .reject { |post| post.data['skip_amp'] }
        .each   { |post| queue << post }

      thread_count.times do
        threads << Thread.new do
          until queue.empty?
            post = queue.pop(true) rescue nil
            if post
              site.pages << AmpPost.new(site, site.source, File.join(dir, post.id), post)
            end
          end
        end
      end

      ThreadsWait.all_waits(*threads)
    end
  end
end
