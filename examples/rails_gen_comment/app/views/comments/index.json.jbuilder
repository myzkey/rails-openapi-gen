json.array! @comments do |comment|
  json.id comment[:id]

  json.content comment[:content]

  json.author comment[:author]

  json.created_at comment[:created_at].iso8601

  json.likes comment[:likes]
end