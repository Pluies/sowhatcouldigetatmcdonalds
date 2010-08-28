class McDoItem

	attr_reader :id, :price, :label, :labelPlural
	attr_accessor :count

	def initialize( id, price, label, labelPlural )
		@id = id
		@price = price
		@label = label
		@labelPlural = labelPlural
		@count = 0
	end

end
