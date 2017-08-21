require 'nokogiri'
require 'csv'
require 'ruby-progressbar'
require 'open-uri'

def load_url(url)
  Nokogiri::HTML(open(url))
end

def load_category_main(url_category)
  $cat = load_url(url_category)
end

def load_category_page(url_category, page_n)
  load_url("#{url_category}?p=#{page_n.to_s}")
end

def get_pages_count()
  $cat.css('ul.pagination.pull-left').css('li')[-2].css('span').children[0].text.to_i
end

def get_links_from_page(page)
  page.css('a.lnk_view').map { |el| el.attributes['href'].value }
end

def get_all_product_links(url_category)
  links = get_links_from_page($cat)
  pages_count = get_pages_count()

  progressbar = ProgressBar.create(title: "Grabbed links from", format: "%t %c/%C pages: |%b>%i|", total: pages_count, starting_at: 1)

  (2..pages_count).each do |page_n|
    page = load_category_page(url_category, page_n)
    links += get_links_from_page(page)
    progressbar.increment
  end
  links
end


def write_empty_product(url)
  File.open('./empty.txt', 'a') { |file| file.write("#{url}\n") }
end


def get_product_info(url)
  product = load_url(url)
  name = product.css('h1')[0].children.last.text.strip

  prices = product.css('ul.attribute_labels_lists').map { |p| p.css('span.attribute_price').text.strip }

  prices = [product.css('span#price_display').text.strip] if prices.empty?

  criterias = product.css('ul.attribute_labels_lists').map { |p| p.css('span.attribute_name').text.strip }
  image = product.css('a.fancybox')[0].attributes['href'].value

  items = []
  (0...prices.length).each do |i|
    items.push({
                   name: criterias[i].nil? ? name : name + ' - ' + criterias[i],
                   price: prices[i],
                   image: image,
               })
  end
  if (items.length.zero?)
    write_empty_product(url)
  end
  return items
rescue Exception => e
  write_empty_product(url)
  items
end


if ARGV.length != 2
  puts "Wrong number of arguments. Aborted"
  exit
end

url_category = ARGV[0].sub(/[\?#].*/, '').sub(/\/+$/, '')
csv_file = ARGV[1]

load_category_main(url_category)
links = get_all_product_links(url_category)

total_items = 0

progressbar = ProgressBar.create(title: "Grabbed", format: "%t %c/%C products: |%b>%i| %E", total: links.length)

CSV.open(csv_file, "w") {}

links.each do |link|
  result = get_product_info(link)
  CSV.open(csv_file, "a") do |csv|
    result.each do |p|
      csv << [p[:name], p[:price], p[:image]]
    end
  end
  total_items += result.length
  progressbar.increment
end

puts "Grabbed #{total_items} items from #{links.length} product pages"
