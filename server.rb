require 'socket'
require 'securerandom'
require './thread_pool.rb'
require './chat_service.rb'

ip_address = '134.226.32.10'
port = '3339'
submit_id = "0105a7b6c410f4f3ae2d2acab136fa2744b7b80012e46ff3214ebb93579a1abc"

pool = ThreadPool.new(10)
chat_service = ChatService.new pool, ip_address, port
server = TCPServer.new(ip_address, port)
puts "Listening on #{ip_address}:#{port}"

loop do
  pool.schedule do
    begin
      client = server.accept_nonblock
      puts "//////////// Accepted connection ////////////////"

      while true
        puts "Awaiting message..."
        begin
          message = client.recv(1000)
          puts "//////Message: ///////\n" << message << "/////////////"
          if message.include? "KILL_SERVICE\n"
            puts "Killing service"
            # Do it in a new thread to prevent deadlock
            Thread.new do
              pool.shutdown
              exit
            end
          elsif message.include? "HELO"
            message.gsub "HELO ", ""
            puts "Giving data dump"
            client.puts message << "IP:#{ip_address}\nPort:#{port.to_s}\nStudentID:#{submit_id}"
          else
            chat_service.handle_messages client, message
          end
          puts "Finished handling message: " << message
       rescue
         puts "No message found.. Going to sleep..."
         # Dont starve the other threads you dick...
         sleep(2)
       end 
     end
     
    rescue
      # DO NOTHING
    end
  end
end





at_exit { pool.shutdown }
