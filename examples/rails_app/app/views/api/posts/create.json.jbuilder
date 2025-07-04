=begin
  @openapi_operation
  summary:"Create new post"
  tags:[Posts,Write]
  description:"Create a new blog post"
  response_description:"Created post with ID and status"
=end

# @openapi success:boolean
json.success true

# @openapi message:string
json.message "Post created successfully"

# @openapi post_id:integer
json.post_id 123

# @openapi created_at:string
json.created_at Time.current.iso8601