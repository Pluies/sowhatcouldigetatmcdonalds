require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require './McDoItem'

# So what could I get at McDonalds?
# v0.1 - Heroku deployment

# Standard pages
get '/' do
	@title = "So what could I get at McDonalds?"
	@price_box = "Depends. How much do you have?"
	@content = "Hit me!"
	haml :index
end

get '/about/?' do
	@title = "About"
	haml :about
end

get '/results/?' do
	@price_box = params['price'].clone # To keep track of the request and display it again in the search box
	if params['price'].match /£|€/
		@title = "You're FOREIGN!?"
		@content = "Désolé / es tut mir leid / mi scusi / sorry mate / het spijt me / lo siento / Мне жаль / jag är ledsen / 对不起: I only accept American Dollars as currency (so far)."
		halt haml :index
	end
	begin
		# Make sure the price is either of the form 00.00$ or $00.00
		params['price'].gsub! /^\$(\d*\.?\d*)$/, '\1'
		params['price'].gsub! /^(\d*\.?\d*)\$$/, '\1'
		price = Float params['price']
	rescue ArgumentError
		@title = "In space, no one will hear you order."
		@content = "I'm afraid I can't do that with something else than a price, Dave." # Debug:  "(you gave me #{params['price']})."
		halt haml :index
	end
	@title = "Results for $%.2f" % price
	Infinity = 1.0/0 # Ooooohhhh... Yes, I'm as terrified as you by the fact that this works
	# Weed out bigbig numbers
	case price
	when 100_000..1_999_999
		@content = "$"+ commify(Integer price)+"? Seriously? A whole lot of food. No, I won't compute that for you. That's too much. You'd become obese and you'd die. I don't want to feel the guilt for the rest of my life. I might be a webserver, but I'm not heartless. Unlike you after eating all that and suffering a stroke. Your little human body is not made for that. It's a no."
		halt haml :index
	when 2_000_000..79_999_999_999
		@content = "Errr, a few franchises?"
		halt haml :index
	when 80_000_000_000..Infinity
		@content = "You could probably buy all of McDonalds stock for that kind of money."
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
				result = result.chomp(', ') + " and " unless order.one?
				result += itemStr+"."
			else
				result += itemStr+", "
			end
		end
		result.gsub!( /^./ ) {|c| c.upcase } # Capitalize only the first letter
		result += if centsLeft >= 1
				  " And you'll even have %.f¢ left!" % centsLeft
			  else
				  " Exact price, neat!"
			  end
		@redo = "I'm somehow dissatisfied. Do it again."
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

# Load prices from the SQLite database to the class array @@menu
def loadAllPrices( dbName )
	@@menu=[]
	@@menu << McDoItem.new(1, 2.69,"Big Mac","Big Macs")
	@@menu << McDoItem.new(2, 2.89, "Quarter Pounder with cheese", "Quarter Pounders with cheese")
	@@menu << McDoItem.new(3, 3.09,"Chicken Selects (3 Pc.)", "")
	@@menu << McDoItem.new(4, 3.79,"McNuggets (10 Pc.)", "")
	@@menu << McDoItem.new(5, 2.49,"Filet-O-Fish", "Filet-O-Fishes")
	@@menu << McDoItem.new(6, 1.49,"Medium beverage", "Medium beverages")
	@@menu << McDoItem.new(7, 1.39,"Medium Fries", "")
	@@menu << McDoItem.new(8, 1.0,"Sundae", "Sundaes")
end

# Searches for a relatively close price in the @@menu
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

# Create the table and populates it with data from menu.txt
#get '/populate/?' do
#	@@db ||= SQLite3::Database.new( "database.db" )
#	@@db.execute( "drop table if exists prices" )
#	@@db.execute( "create table prices( price float(5.2), label varchar(120), labelPlural varchar(120) )" )	
#	File::readlines("menu.txt").each do |line|
#		if line =~ /.*:.*/
#			valuesToInsert = line.chomp.split(':')
#			case valuesToInsert.count
#			when 2 # If there's no plural defined, split only gives 2 values
#				@@db.execute 'insert into prices(price, label, labelPlural) values (%s, "%s", "")' % valuesToInsert
#			when 3
#				@@db.execute 'insert into prices(price, label, labelPlural) values (%s, "%s", "%s")' % valuesToInsert
#			end
#		end
#	end
#	@title = "Population complete."
#	haml :populate
#end

get '/stylesheet.css' do
	content_type 'text/css', :charset => 'utf-8'
	sass :stylesheet
end

# Error pages
not_found do
	'Page not found. How the hell did you get there?'
end

# Templates


