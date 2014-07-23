require "spec_helper"

describe ActiveRecord::ConnectionAdapters::RedshiftAdapter do
  before(:all) do
    @connection =  ActiveRecord::Base.redshift_connection(TEST_CONNECTION_HASH)

    [
      'DROP SCHEMA test CASCADE',
      'CREATE SCHEMA test',
      'DROP TABLE public.test',
      'DROP TABLE public.test2',
      'DROP TABLE test.test',
      'DROP TABLE test.test2',
    ].each do |query|
      begin
        @connection.query(query)
      rescue
      end
    end

    @connection.query <<-sql
    CREATE TABLE public.test ( "id" INTEGER NULL, "name" VARCHAR(80) NULL );
    CREATE TABLE public.test2 ( "id" INTEGER, "name" VARCHAR );
    INSERT INTO public.test VALUES (1, 'first');
    INSERT INTO public.test VALUES (2, 'second');
    CREATE TABLE test.test ( "id" INTEGER NOT NULL, "is" BOOL NOT NULL );
    CREATE TABLE test.test2 ( "id" INTEGER, "is" BOOL );
    sql
  end

  after(:all) do
    @connection.query <<-sql
    DROP TABLE public.test, public.test2, test.test, test.test2;
    sql
  end

  describe "#initialize" do
    it "opens a connection" do
      @connection.active?.should be_true
    end
  end

  describe "#tables" do
    it "returns all tables in public schema" do
      @connection.schema_search_path = "public"
      @connection.tables.should == ["public.test", "public.test2"]
    end

    it "returns all tables in all schemas" do
      @connection.schema_search_path = "public, test"
      @connection.tables.should == ["public.test", "public.test2", "test.test", "test.test2"]
    end
  end

  describe "#columns" do
    it "returns all columns in table in public schema" do
      id = ActiveRecord::ConnectionAdapters::RedshiftColumn.new("id", "", "integer", true)
      name =  ActiveRecord::ConnectionAdapters::RedshiftColumn.new("name", "", "character varying(80)", true)
      @connection.columns("test").should == [id, name]
    end

    it "returns all columns in table" do
      id = ActiveRecord::ConnectionAdapters::RedshiftColumn.new("id", "", "integer", false)
      is =  ActiveRecord::ConnectionAdapters::RedshiftColumn.new("is", "", "boolean", false)
      @connection.columns("test.test").should == [id, is]
    end
  end

  describe "#table_exists?" do
    it "checks if table in schema exists" do
      @connection.table_exists?("public.test").should be_true
    end

    it "checks if unknown table in schema doesn't exist" do
      @connection.table_exists?("public.null").should be_false
    end

    it "checks if table in implied schema exists" do
      @connection.table_exists?("test2").should be_true
    end
  end

  describe "#current_database" do
    it "returns current database" do
      @connection.current_database.should == TEST_CONNECTION_HASH[:database]
    end
  end

  describe "#schema_search_path" do
    it "returns current database" do
      @connection.schema_search_path = '"$user", public'
      @connection.schema_search_path.should == '"$user", public'
    end
  end

  describe "#update_sql" do
    it "returns the number of updated rows" do
      @connection.update_sql("UPDATE public.test SET name = 'test'").should == 2
    end
  end

  describe "#quote_string" do
    it "quotes the string without surrouding quotes" do
      @connection.quote_string("quote'd").should == "quote''d"
    end

    it "returns identical string when no quoting is required" do
      @connection.quote_string("quote").should == "quote"
    end
  end

  describe "#quote_column_name" do
    it "can handle a bunch of different cases" do
      tests = {
        'quote'         => '"quote"',
        'qu"ote'        => '"qu""ote"',
        'qu"""ote'      => '"qu""""""ote"',
        'foo "bar" baz' => '"foo ""bar"" baz"',
        ' quote '       => '" quote "',
        ''              => '""',
        'q'*127         => "\"#{'q' * 127}\"", # this one will fail if we use PGConn.quote_ident
      }

      tests.each do |input, output|
        @connection.quote_column_name(input).should == output
      end
    end
  end
end
