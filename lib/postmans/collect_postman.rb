class CollectPostman
  def initialize
    @mails = []
  end

  def mail options={}
    @mails << options
  end
end
