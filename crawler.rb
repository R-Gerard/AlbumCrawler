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

require 'open-uri'
require 'json'

def get_page(url)
  return nil if url.nil? || url.empty?

  begin
    page = JSON.parse(open(URI.encode(url)).read)
  rescue Exception => e
    # For some reason the last page has a "next" link that doesn't work
    puts e.message
    puts e.backtrace
    return nil
  end

  # The first page's data is wrapped in a "photos" or "albums" element
  page = page['photos'] if page.has_key?('photos')
  page = page['albums'] if page.has_key?('albums')

  data = page['data'] || []
  next_url = page.has_key?('paging') ? page['paging']['next'] : nil

  Hash['data', data, 'next_url', next_url]
end

def get_image_data(page)
  return {} if page.nil? || page.empty?

  images = {}
  page['data'].each do |item|
    begin
      name = item['name'].split("\n").select { |line| line.downcase.include?('grandiloquent word of the day:') }.first.split(':').last.strip
    rescue
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

def get_albums(page_id)
  return {} if page_id.nil? || page_id.empty?

  albums = {}
  url = "http://graph.facebook.com/#{page_id}?fields=albums"
  loop do
    puts "Fetching album data from: #{url}"
    page = get_page(url)

    break if page.nil?

    albums.merge!(get_album_metadata(page))
    url = page['next_url']
  end

  albums
end

def get_photos(album_id)
  return if album_id.nil? || album_id.empty?

  #photos = {}
  url = "http://graph.facebook.com/#{album_id}?fields=photos"
  loop do
    puts "Fetching image data from: #{url}"
    page = get_page(url)

    break if page.nil?

    #photos.merge!(get_image_data(page))
    photos = get_image_data(page)
    url = page['next_url']

    # TODO: Actually download the photos
    puts JSON.pretty_generate(photos)
  end
end

# Given a page-id and album name (e.g. 'Timeline Photos'), get the album-id
url = 'http://www.facebook.com/pages/Grandiloquent-Word-of-the-Day/479146505433648'
page_id = url.split('/').last

albums = get_albums(page_id)
puts 'Found the following albums:'
puts JSON.pretty_generate(albums)

album_id = albums['Timeline Photos']
get_photos(album_id)
