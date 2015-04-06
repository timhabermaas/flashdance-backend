require "command_handlers"

class App
  def initialize(database_url, logging=true)
    loggers = logging ? [Logger.new($stdout)] : []
    @connection = Sequel.connect(database_url, loggers: loggers)
    require "models"
  end

  def handle(command)
    {
      Commands::CreateRow => handler { |c| DBModels::Row.create(y: c.y, number: c.number) },
      Commands::CreateSeat => handler { |c| DBModels::Seat.create(x: c.x, number: c.number, usable: c.usable, row_id: c.row_id) },
      Commands::CreateGig => handler { |c| DBModels::Gig.create(title: c.title, date: c.date) }
    }.fetch(command.class).handle(command)
  end

  def clean_db!
    @connection[:seats].delete
    @connection[:rows].delete
    @connection[:gigs].delete
  end

  def migrate!
    Sequel.extension :migration, :core_extensions
    Sequel::Migrator.run(connect, File.dirname(__FILE__) + '/../migrations')
  end

  private
    def handler(&block)
      CommandHandlers::GenericHandler.new(&block)
    end
end
