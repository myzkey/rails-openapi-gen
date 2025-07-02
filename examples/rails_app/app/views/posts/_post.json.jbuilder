# @openapi id:integer description:"Post unique identifier"
json.id post.id

# @openapi title:string description:"Post title"
json.title post.title

# @openapi content:string description:"Post content body"
json.content post.content

# @openapi published:boolean description:"Whether the post is published"
json.published post.published

# @openapi created_at:string format:date-time description:"Post creation timestamp"
json.created_at post.created_at.iso8601

# @openapi updated_at:string format:date-time description:"Last update timestamp"
json.updated_at post.updated_at.iso8601