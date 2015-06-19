class PrintPostman
  def mail options={}
    puts "SENDING MAIL TO #{options[:to]}"
    puts "== BODY =="
    puts options[:body]
    puts "== /BODY =="
  end
end
