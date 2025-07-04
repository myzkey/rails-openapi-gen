# @openapi id:integer description:"Unique post identifier"
json.id post.id

# @openapi title:string description:"Post title"
json.title post.title

# @openapi content:string description:"Post content/body"
json.content post.content

# @openapi published:boolean description:"Whether the post is published"
json.published post.published

# @openapi created_at:string description:"Post creation timestamp in ISO 8601 format"
json.created_at post.created_at.iso8601

json.updated_at post.updated_at.iso8601