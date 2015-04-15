module QueryHandlers
  class GenericHandler
    def initialize(&lambda)
      @lambda = lambda
    end

    def answer(command)
      @lambda.call command
    end
  end
end
