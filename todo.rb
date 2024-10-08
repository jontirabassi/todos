require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end
  
  def list_class(list)
    "complete" if list_complete?(list)
  end
  
  def todos_count(list)
    list[:todos].size
  end
  
  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end
  
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
  
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
  
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
  
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of all lists
get "/lists" do
   @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name }
    "List name must be unique."
  end
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

#Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]
  
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, complete: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete a todo from a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:id].to_i
  
  @list[:todos].delete_at todo_id
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed
  
  if is_completed == true
    session[:success] = "The todo has been marked completed"
  else
    session[:success] = "The todo has been marked uncompleted"
  end
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete for a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  
  session[:success] = "All todos have been completed"
  redirect "/lists/#{@list_id}"
end