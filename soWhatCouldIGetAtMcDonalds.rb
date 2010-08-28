require 'rubygems'
require 'sinatra'
require 'haml'
require 'sqlite3'
require 'McDoItem'

# So what could I get at McDonalds?
# v0.1 - Heroku deployment

# Standard pages
get '/' do
	@title = "So what could I get at McDonalds?"
	@content = "Hit me!"
	haml :index
end

get '/results/?' do
	begin
		price = Float params['price']
	rescue ArgumentError
		@title = "In space, no one will hear you scream."
		@content = "I'm afraid I can't do that with something else than a number, Dave."
		halt haml :index
	end
	@title = "Results for $%.2f" % price
	# Weed out bigbig numbers
	Infinity = 1.0/0 # Ooooohhhh... I'm terrified by the fact that this works
	case price
	when 100_000..1_999_999
		@content = "$"+ commify(Integer price)+"? Seriously? A whole lot of food. No, I won't compute that for you. That's too much. You'd become obese and you'd die. I don't want to feel the guilt for the rest of my life. I might be a webserver, but I'm not heartless. Unlike you after eating all that and suffering a stroke. Your little human heart is not made for that. It's a no."
		halt haml :index
	when 2_000_000..399_999_999
		@content = "Errr, $"+ commify(Integer price)+"? A few franchises."
		halt haml :index
	when 400_000_000..Infinity
		@content = "$"+ commify(Integer price)+"? You could probably buy all of McDonalds stock for that kind of money."
		halt haml :index
	end

	loadAllPrices "database.db"
	# Create the blacklist from the GET parameter 'without'
	if params['without'] != nil
		blacklist = []
		params['without'].split(',').each do |blacklistedItem|
			blacklist = blacklist+[blacklistedItem.to_i]
		end
		@@menu = @@menu.delete_if{ |item| blacklist.include? item.id }
	end
	result = ""
	order = searchForClosePrice price
	# Kludge. To avoid recomputing the price, we hide it inside the hash containing the items, get it back, then delete it from the hash
	centsLeft = order['price'] * 100
	order.delete 'price'
	if order.empty?
		@content = "Nothing found. "
		@content += if price < 1
				    "Maybe if you had, like... More than a dollar?"
	    		    else
				    "You're a bit picky, aren't you?"
			    end
		halt haml :index
	else
		order = order.sort_by{|label, item| item.count }.reverse
		order.each do |label, item|
			# Prettyprinting: quantities
			if item.count > 1 and item.labelPlural != ''
				itemStr = item.labelPlural
			else
				itemStr = item.label
			end
			prefix = case item.count
				 when 1
					 "a "
				 when 12
					 "a dozen "
				 else
					 item.count.to_s+" "
				 end
			itemStr = prefix + '<div id="mcdo_' + item.id.to_s + '" class="mcdo_item" >' + itemStr + '</div>'
			# Prettyprinting: punctuation
			if item.label == order.last[0]
				if order.length > 1
					result = result.chomp(', ') + " and "
				end
				result += itemStr+"."
			else
				result += itemStr+", "
			end
		end
		result.gsub!( /^./ ) {|c| c.upcase } # Capitalize only the first letter
		result += if centsLeft >= 1
				  " And you'll even have %.0f¢ left!" % centsLeft
			  else
				  " Exact price, neat!"
			  end
		@redo = "I'm somehow dissatisfied."
		@content = result
		haml :index
	end
end

# Shamelessly borrowed from the Programming Language Examples Alike Cookbook :3
# ( http://pleac.sourceforge.net/pleac_ruby/numbers.html )
def commify(n)
	n.to_s =~ /([^\.]*)(\..*)?/
		int, dec = $1.reverse, $2 ? $2 : ""
	while int.gsub!(/(,|\.|^)(\d{3})(\d)/, '\1\2,\3')
	end
	int.reverse + dec
end


def loadAllPrices( dbName )
	@@menu=[]
	@@db ||= SQLite3::Database.new( dbName )
	@@db.execute("select rowid, price, label, labelPlural from prices") do |row|
		@@menu << McDoItem.new( row[0], row[1], row[2], row[3] )
	end
end

def searchForClosePrice( price )
	# Our order is an hash of itemLabel (String) => item (McDoItem)
	order = {}
	noPriceCanBeFound = false # Optimistic!
	until noPriceCanBeFound
		noPriceCanBeFound = true
		# NB: performance hit due to shuffle() each time.
		# A better solution would be to pick an item with @@menu[rand(@@menu.size)],
		# but then we'll have to deal with what happens if this item is too expensive.
		# TODO: see if the performance improvement is worth complicating the code.
		@@menu.shuffle.each do |item|
			if item.price <= price
				order[item.label] ||= item
				order[item.label].count += 1
				noPriceCanBeFound = false
				price -= item.price
				break
			end
		end
	end
	order['price'] = price
	order
end

get '/populate/?' do
	@@db ||= SQLite3::Database.new( "database.db" )
	@@db.execute( "drop table if exists prices" )
	@@db.execute( "create table prices( price float(5.2), label varchar(120), labelPlural varchar(120) )" )	
	File::readlines("menu.txt").each do |line|
		if line =~ /.*:.*/
			valuesToInsert = line.chomp.split(':')
			case valuesToInsert.count
			when 2 # If there's no plural defined, split only gives 2 values
				@@db.execute 'insert into prices(price, label, labelPlural) values (%s, "%s", "")' % valuesToInsert
			when 3
				@@db.execute 'insert into prices(price, label, labelPlural) values (%s, "%s", "%s")' % valuesToInsert
			end
		end
	end
	@title = "Population complete."
	haml :populate
end

get '/stylesheet.css' do
	content_type 'text/css', :charset => 'utf-8'
	sass :stylesheet
end

# Error pages
not_found do
	'Page not found. How the hell did you get there?'
end

# Templates

