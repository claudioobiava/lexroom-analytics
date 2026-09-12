import duckdb

connection = duckdb.connect("lexroom.duckdb", read_only=True)
connection.execute("SET TimeZone='UTC'")

with open("query.sql") as f:
    connection.sql(f.read()).show(max_rows=200)