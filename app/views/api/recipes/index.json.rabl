child @recipes => :recipes do
  attributes :id, :brand, :total_time_display, :active_time_display
  attributes :pretty_name => :name

  node(:thumbnail) do |recipe|
    {
      url: recipe.thumbnail_image&.image_url(:tiny)
    }
  end
end

node(:total_pages) do
  total_pages
end

node(:total) do
  total
end

node(:page_length) do
  page_length
end

