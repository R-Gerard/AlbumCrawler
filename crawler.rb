# Copyright (C) 2014 Rusty Gerard
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'fileutils'
require 'open-uri'
require 'json'
require 'cgi'

def download(items)
  FileUtils.mkdir_p('out')

  items.each do |name, source|
    print '.'
    $stdout.flush
    next if File.exists?("out/#{name}.jpg")

    open("out/#{name}.jpg", 'wb') do |file|
      file << open(source).read
    end
  end
  puts ''
end

def get_page(url, limit=32, message='', retry_count=0)
  return nil if url.nil? || url.empty? || limit == 0

  # The Graph API's hypermedia sets the results limit to 25, so we will adjust it as we see fit
  uri = URI.parse(url)
  query = CGI::parse(uri.query)
  query['limit'] = limit if query.has_key?('limit')
  uri.query = URI.encode_www_form(query)

  puts message.rstrip + ' ' + uri.to_s

  begin
    page = JSON.parse(uri.open.read)
  rescue Exception => e
    # The Graph API's pagination is slightly broken; if we request more results than what actually exists we get a 400 error back
    return get_page(url, limit / 2, 'Request failed. Retrying with:', retry_count + 1)
  end

  # The first page's data is wrapped in a "photos" or "albums" element
  page = page['photos'] if page.has_key?('photos')
  page = page['albums'] if page.has_key?('albums')

  data = page['data'] || []
  next_url = page.has_key?('paging') ? page['paging']['next'] : nil

  Hash['data', data, 'next_url', next_url, 'retry_count', retry_count]
end

def get_image_data(page)
  return {} if page.nil? || page.empty?

  images = {}
  page['data'].each do |item|
    begin
      name = item['name'].split("\n").select { |line| line.downcase.include?('grandiloquent word of the day:') }.first.split(':').last.strip
    rescue
      # Default to the unique image-id
      # Note: you can view this image on Facebook at "http://www.facebook.com/photo.php?fbid=#{id}"
      name = item['id']
    end
    images[name] = item['source']
  end

  images
end

def get_album_metadata(page)
  return {} if page.nil? || page.empty?

  metadata = {}
  page['data'].each do |item|
    name = item['name']
    id = item['id']
    metadata[name] = id
  end

  metadata
end

def get_metadata(page, fields)
  return get_album_metadata(page) if fields == 'albums'
  return get_image_data(page) if fields == 'photos'
  return {}
end

def get_hypermedia(id, fields)
  return {} if id.nil? || id.empty? || fields.nil? || fields.empty?

  limit = 64
  results = {}
  url = "http://graph.facebook.com/#{id}?fields=#{fields}"
  loop do
    break if url.nil? || url.empty?

    page = get_page(url, limit, "Fetching #{fields.chomp('s')} data from:")

    break if page.nil?

    new_results = get_metadata(page, fields)
    limit = new_results.size if page['retry_count'] > 0
    puts "Found #{new_results.size} results"
    results.merge!(new_results)
    url = page['next_url']

    download(new_results) if fields == 'photos'
  end

  results
end

# Given a page-id and album name (e.g. 'Timeline Photos'), get the album-id
url = 'http://www.facebook.com/pages/Grandiloquent-Word-of-the-Day/479146505433648'
page_id = url.split('/').last

albums = get_hypermedia(page_id, 'albums')
puts 'Found the following albums:'
puts JSON.pretty_generate(albums)

album_id = albums['Timeline Photos']
get_hypermedia(album_id, 'photos')

puts 'All done!'
