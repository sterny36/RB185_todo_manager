require "pg"
require "pry"

class DatabasePersistence

  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(statement, *params)
    @logger.info("#{statement}: #{params}")
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = 'SELECT * FROM lists WHERE id = $1'
    sql = <<~SQL
      SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      WHERE list_id = $1
      GROUP BY lists.id;
    SQL
    tuple = query(sql, id).first
    tuple_to_list_hash(tuple)
  end

  def all_lists
    sql = <<~SQL
      SELECT lists.*,
      COUNT(todos.id) AS todos_count,
      COUNT(NULLIF(todos.completed, true)) AS todos_remaining_count
      FROM lists
      LEFT JOIN todos ON todos.list_id = lists.id
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, name)
  end

  def delete_list(id)
    query("DELETE FROM todos WHERE list_id = $1", id)
    query("DELETE FROM lists WHERE id = $1", id)
  end

  def update_list_name(id, list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, list_name, id)
  end

  def create_new_todo(list_id, text)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, text)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 AND id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, is_completed)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, is_completed,list_id, todo_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true  WHERE list_id = $1"
    query(sql, list_id)
  end

  def find_todos_for_list(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    todos = query(sql, list_id)
    todos.map do |todo|
      {id: todo["id"].to_i , name: todo["name"] , completed: todo["completed"] == "t" }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    {
      id: tuple["id"].to_i,
      name: tuple["name"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i
    }
  end

end
