json.array! @posts do |post|
  json.id post[:id]

  json.title post[:title]

  json.content post[:content]

  json.published post[:published]

  json.created_at post[:created_at].iso8601

  json.tags @post[:tags] do |tag|
    json.name tag[:name]
    json.color tag[:color]
  end

end