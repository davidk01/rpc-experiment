# Handles nonsense related to readpartial and various other
# socket vagaries.
class PartialReader

  def initialize(connection)
    @connection = connection
  end

  def read_partial_until(wanted_buffer_length)
    $logger.debug "Wanted buffer length: #{wanted_buffer_length}."
    buffer = ""
    while (current_buff_length = buffer.length) < wanted_buffer_length
      $logger.debug "Current buffer length: #{current_buff_length}."
      buffer << @connection.readpartial(wanted_buffer_length - current_buff_length)
    end
    buffer
  end
  
end