# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

[
  { title: "Welcome to Ruby Native", body: "This demo app shows a Rails app turned native with the ruby_native gem." },
  { title: "Native tabs, no Swift or Kotlin", body: "The gem wraps this Rails app with a native tab bar using Hotwire Native." },
  { title: "Posts are just a demo", body: "This simple posts form exists to show data flowing through a real DB." }
].each do |attrs|
  Post.find_or_create_by!(title: attrs[:title]) { |post| post.body = attrs[:body] }
end
