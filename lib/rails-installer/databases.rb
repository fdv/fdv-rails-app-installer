require 'active_record'

class RailsInstaller
  
  # Parent class for database plugins for the installer.  To create a new 
  # database handler, subclass this class and define a +yml+ class and
  # optionally a +create_database+ method.
  class Database
    @@db_map = Hash.new(self)

    # Connect to the database (using the 'database.yml' generated by the +yml+
    # method).  Returns true if the database already exists, and false if the
    # database doesn't exist yet.
    def self.connect(installer)
      database_yml = File.read File.join(installer.install_directory, 'config', 'database.yml') rescue nil
      database_yml ||= yml(installer)
      
      environment = ENV['RAILS_ENV'] || 'development' # Mirror Rails' default.
      
      ActiveRecord::Base.establish_connection( 
        YAML.load(database_yml)[environment])
      begin
        tables = ActiveRecord::Base.connection.tables
        if tables.size > 0
          return true
        end
      rescue Exception
        # okay
      end
      return false
    end
    
    # Back up the database.  This is fully DB and schema agnostic.  It
    # serializes all tables to a single YAML file.
    def self.backup(installer)
      return unless connect(installer)
      
      interesting_tables = ActiveRecord::Base.connection.tables.sort - ['sessions']
      backup_dir = File.join(installer.install_directory, 'db', 'backup')
      FileUtils.mkdir_p backup_dir
      backup_file = File.join(backup_dir, "backup-#{Time.now.strftime('%Y%m%d-%H%M')}.yml")

      installer.message "Backing up to #{backup_file}"
      
      data = {}
      interesting_tables.each do |tbl|
        data[tbl] = ActiveRecord::Base.connection.select_all("select * from #{tbl}")
      end

      File.open(backup_file,'w') do |file|
        YAML.dump data, file
      end
    end
    
    # Restore a backup created by +backup+.  Deletes all data before 
    # importing.
    def self.restore(installer, filename)
      connect(installer)
      data = YAML.load(File.read(filename))
      
      installer.message "Restoring data"
      data.each_key do |table|
        if table == 'schema_info'
          ActiveRecord::Base.connection.execute("delete from schema_info")
          ActiveRecord::Base.connection.execute("insert into schema_info (version) values (#{data[table].first['version']})")
        else
          installer.message " Restoring table #{table} (#{data[table].size})"

          # Create a temporary model to talk to the DB
          eval %Q{
          class TempClass < ActiveRecord::Base
            set_table_name '#{table}'
            reset_column_information
          end
          }
          
          TempClass.delete_all
                
          data[table].each do |record|
            r = TempClass.new(record)
            r.id = record['id'] if record.has_key?('id')
            r.save
          end
          
          if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
            ActiveRecord::Base.connection.reset_pk_sequence!(table)
          end
        end
      end
    end
  
    # Create a 'database.yml' file, using the data from +yml+.
    def self.database_yml(installer)
      yml_file = File.join(installer.install_directory,'config','database.yml')
      return if File.exists? yml_file
      
      File.open(yml_file,'w') do |f|
        f.write(yml(installer))
      end
    end
    
    # Create the database, including schema creation.  This should be generic
    # enough that database-specific drivers don't need to override it.
    #
    # It calls +create_database+ to actually build a new DB from scratch if
    # needed.
    def self.create(installer)
      installer.message "Checking database"
      if connect(installer)
        installer.message "Database exists, preparing for upgrade"
        return
      end

      installer.message "Creating initial database"
      
      create_database(installer)
      
      schema_file = File.join(installer.install_directory,'db',"schema.#{installer.config['database']}.sql")
      schema = File.read(schema_file)
      
      # Remove comments and extra blank lines
      schema = schema.split(/\n/).map{|l| l.gsub(/^--.*/,'')}.select{|l| !(l=~/^$/)}.join("\n")
      
      schema.split(/;\n/).each do |command|
        ActiveRecord::Base.connection.execute(command)
      end
    end
    
    # Create a new database from scratch.  Some DBs, like SQLite, don't need
    # this.  Others will need to override this and call the DB's "create new 
    # database" command.
    def self.create_database(installer)
      # nothing
    end

    # Inheritence hook
    def self.inherited(sub)
      name = sub.to_s.gsub(/^.*::/,'').gsub(/([A-Z])/) do |match|
        "_#{match.downcase}"
      end.gsub(/^_/,'')

      @@db_map[name] = sub
    end
    
    def self.dbs
      @@db_map
    end
    
    # Database host name
    def self.db_host(installer)
      installer.config['db_host'] || 'localhost'
    end
    
    # Database user name
    def self.db_user(installer)
      installer.config['db_user'] || ENV['USER'] || installer.app_name 
    end
    
    # Database name
    def self.db_name(installer)
      installer.config['db_name'] || installer.app_name
    end
  
    # The driver for SQLite 3.  This is pretty minimal, as all we need is a
    # +yml+ class to provide a basic 'database.yml'.
    class Sqlite < RailsInstaller::Database
      # The name of the sqlite database file
      def self.db_file(installer)
        File.join(installer.install_directory,'db','database.sqlite')
      end
      
      def self.yml(installer)
        %q{
        login: &login
          adapter: sqlite3
          database: db/database.sqlite

        development:
          <<: *login

        production:
          <<: *login

        test:
          database: ":memory:"
          <<: *login
        }        
      end
    end
    
    # A PostgreSQL driver.  This is a bit more work then the SQLite driver, as
    # Postgres needs to talk to its server.  So it takes a number of config
    # variables:
    #
    #  * db_host
    #  * db_name
    #  * db_user
    #  * db_password
    #
    # It will call +createdb+ to set up the db all on its own.
    class Postgresql < RailsInstaller::Database
      def self.yml(installer)
        %Q{
        login: &login
          adapter: postgresql
          host: #{db_host installer}
          username: #{db_user installer}
          password: #{installer.config['db_password']}
          database: #{db_name installer}

        development:
          <<: *login

        production:
          <<: *login

        test:
          database: #{db_name installer}-test
          <<: *login
        }        
      end
      
      # Create a PostgreSQL database.
      def self.create_database(installer)
        installer.message "Creating PostgreSQL database"
        system("createdb -U #{db_user installer} #{db_name installer}")
        system("createdb -U #{db_user installer} #{db_name installer}-test")
      end
    end
    
    # Mysql DB class, thanks Phillip Toland
    class Mysql < RailsInstaller::Database
      def self.yml(installer)
        %Q{
        login: &login
          adapter: mysql
          host: #{db_host installer}
          username: #{db_user installer}
          password: #{installer.config['db_password']}
          database: #{db_name installer}

        development:
          <<: *login

        production:
          <<: *login

        test:
          database: #{db_name installer}_test
          <<: *login
        }
      end

      # Create a MySQL database.
      def self.create_database(installer)
        installer.message "Creating MySQL database"
        base_command = "mysql -u #{db_user installer} "
        base_command << "-p#{installer.config['db_password']}" if installer.config['db_password']
        system("#{base_command} -e 'create database #{db_name installer}'")
        system("#{base_command} -e 'create database #{db_name installer}_test'")
      end
    end
  end
end
