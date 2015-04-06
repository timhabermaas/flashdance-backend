module CommandHandlers
  class GenericHandler
    def initialize(&lambda)
      @lambda = lambda
    end

    def handle(command)
      @lambda.call command
    end
  end
end
