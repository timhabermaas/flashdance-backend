class Result
end

class Ok < Result
  def initialize(value)
    @value = value
  end

  def success?
    true
  end

  def and_then
    yield @value
  end

  def on_error
    self
  end

  def unwrap
    @value
  end
end

def Ok(value)
  Ok.new value
end

class Error < Result
  def initialize(value)
    @value = value
  end

  def success?
    false
  end

  def and_then
    self
  end

  def on_error
    yield @value
  end

  def unwrap
    raise "can't unwrap Error"
  end
end

def Error(value)
  Error.new value
end
