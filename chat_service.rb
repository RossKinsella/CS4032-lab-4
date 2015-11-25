class ChatService

  

  def initialize(thread_pool, ip_address, port)
    @pool = thread_pool
    @ip_address = ip_address
    @port = port
    @room_references = Hash.new
    @joins = Hash.new
    @chat_room_memberships = Hash.new []
  end

  def handle_messages client, message
    puts "handle messages"

    

    if message.include? "KILL_SERVICE"
      puts "Killing service..."
      # Do it in a new thread to prevent deadlock
      Thread.new do
        @pool.shutdown
        exit
      end
    elsif message.include? "JOIN_CHATROOM:"
      puts "Client is joining a chatroom...."

      # Get arguments
      chatroom_name = get_message_param message, "JOIN_CHATROOM"
      client_name = get_message_param message, "CLIENT_NAME"
      puts "chatroom name: #{chatroom_name}"
      puts "client name: #{client_name}"
      join_chatroom(client, chatroom_name, client_name)
      puts "Joining chatroom COMPLETE"
    elsif message.include? "LEAVE_CHATROOM:"
      puts "Leave chatroom...."

      chatroom_name = get_message_param message, "LEAVE_CHATROOM"
      join_id = get_message_param message, "JOIN_ID"
      client_name = get_message_param message, "CLIENT_NAME"

      leave_chatroom client, chatroom_name, join_id, client_name
      puts "Leave chatroom COMPLETE..."
    elsif message.include? "CHAT:"
      puts "Chating...."

      room_ref = get_message_param message, "CHAT"
      join_id = get_message_param message, "JOIN_ID"
      client_name = get_message_param message, "CLIENT_NAME"
      message = get_message_param message, "MESSAGE"

      chat client, room_ref, join_id, client_name, message
      puts "Chating COMPLETE"
    elsif message.include? "DISCONNECT :"
      puts "Disconnecting...."

      disconnect client
      puts "Disconect COMPLETE"
    else
      puts "Unsupported message."
      client.puts "go away\nseriously, get lost\nBEGONE"
      puts "Told the client off."
    end
  end

  # ################
  # Request
  # JOIN_CHATROOM: [chatroom name]
  # CLIENT_IP: [IP Address of client if UDP | 0 if TCP]
  # PORT: [port number of client if UDP | 0 if TCP]
  # CLIENT_NAME: [string Handle to identifier client user]
  # ################
  # Response
  # ################
  # JOINED_CHATROOM: [chatroom name]
  # SERVER_IP: [IP address of chat room]
  # PORT: [port number of chat room]
  # ROOM_REF: [integer that uniquely identifies chat room on server]
  # JOIN_ID: [integer that uniquely identifies client joining]
  def join_chatroom(client, chatroom_name, client_name)
    join_id = generate_identifier
    @joins[join_id] = client

    room_id = ""
    if @room_references[chatroom_name]
      room_id = @room_references[chatroom_name]
    else
      room_id = generate_identifier
      @room_references[chatroom_name] = room_id
    end

    @chat_room_memberships[room_id].push join_id

    response = 
"JOINED_CHATROOM: #{chatroom_name}
SERVER_IP: #{@ip_address}
PORT: #{@port}
ROOM_REF: #{room_id}
JOIN_ID: #{join_id}"

    message_clients_in_room room_id, "CHAT: #{room_id}\nCLIENT_NAME: #{client_name}\nMESSAGE: #{client_name} has joined this chatroom."
    client.puts response

    #message_clients_in_room room_id, "CHAT: #{room_id}\nCLIENT_NAME: #{client_name}\nMESSAGE: #{client_name} has joined this chatroom."
  end
  # ################
  # Request
  # LEAVE_CHATROOM: [ROOM_REF]
  # JOIN_ID: [integer previously provided by server on join]
  # CLIENT_NAME: [string Handle to identifier client user]
  # ################
  # Response
  # ################
  # LEFT_CHATROOM: [ROOM_REF]
  # JOIN_ID: [integer previously provided by server on join]
  def leave_chatroom client, room_id, join_id, client_name
    puts "Leaving chatroom..."
    puts "Room #{room_id} members were: @chat_room_memberships[room_id.to_i]"
    @chat_room_memberships[room_id.to_i] - [join_id.to_i]
    
    puts "Room #{room_id} members are now: @chat_room_memberships[room_id.to_i]"
    response = 
"LEFT_CHATROOM: #{room_id}
JOIN_ID: #{join_id}"

    client.puts respose

    message_clients_in_room room_id, "CHAT: #{room_id}\nCLIENT_NAME: #{client_name}\nMESSAGE: #{client_name} has left this chatroom."
  end

  # ################
  # Request
  # CHAT: [ROOM_REF]
  # JOIN_ID: [integer identifying client to server]
  # CLIENT_NAME: [string identifying client user]
  # MESSAGE: [string terminated with '\n\n']
  # ################
  # Response
  # To every client connected to the room
  # ################
  # CHAT: [ROOM_REF]
  # CLIENT_NAME: [string identifying client user]
  # MESSAGE: [string terminated with '\n\n']
  def chat client, room_ref, join_id, client_name, message

    response = 
"CHAT: #{room_ref}
CLIENT_NAME: #{client_name}
MESSAGE: #{message}"
    
    message_clients_in_room room_ref, response
  end

  # ################
  # Request
  # ################
  # DISCONNECT: [IP address of client if UDP | 0 if TCP]
  # PORT: [port number of client it UDP | 0 id TCP]
  # CLIENT_NAME: [string handle to identify client user]
  # ################
  # Response
  # ################
  # Terminates the conneciton
  def disconnect client
    puts "Closing"
    client.close
    puts "Closed"
  end

  def message_clients_in_room room_ref, message
    @chat_room_memberships[room_ref].each do |member|
      @joins[member].puts message
    end
  end

  def generate_identifier
    SecureRandom.uuid.gsub("-", "").hex
  end

  def get_message_param message, param
    param_start = message.index param
    param_end = -1
    if message[param_start..-1].include? "\n"
      param_end = message[param_start..-1].index("\n") + param_start
    end

    res = message[param_start..param_end]
    res = res.gsub(param << ":", "")
    res = res.gsub(param << ": ", "")
    
    if res.include? "\n"
      res.gsub! "\n", ""
    end
    res
  end
end
