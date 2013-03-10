module PartialReaderDSL

class Instruction; end

class Consumer < Instruction
  
  def initialize(count)
    @count = count
  end
  
  def call(context, connection)
    return_value = :call_again
    if (buffer = context.buffer).length < @count
      context.buffer << connection.readpartial(@count - buffer.length)
    else
      return_value = :done
    end
    return_value
  end
  
end

class BufferTransform < Instruction
  
  def initialize(&blk)
    @blk = blk
  end
  
  def call(context, connection)
    @blk.call(context); context.empty_buffer!; :delay_call
  end
  
end

class PartialReaderMachine
  
  def self.protocol(&blk)
    current_instance = new
    blk.call(current_instance)
    current_instance
  end
  
  attr_reader :buffer, :return_stack
  
  def initialize
    @buffer, @return_stack = "", []
    @instruction_sequence, @instruction_pointer = [], 0
  end
  
  def current_instruction
    @instruction_sequence[@instruction_pointer]
  end
  
  def call(connection)
    if (current_instr = current_instruction).nil?
      return @return_stack
    end
    case (status = current_instr.call(self, connection))
    when :done
      @instruction_pointer += 1
      call(connection)
    when :delay_call
      @instruction_pointer += 1
    when :call_again
    else
      throw :unknown_return_code, status
    end
  end
  
  def consume(count)
    @instruction_sequence << Consumer.new(count)
  end
  
  def return(value)
    @return_stack << value
  end
  
  def buffer_transform(&blk)
    @instruction_sequence << BufferTransform.new(&blk)
  end
  
  def empty_buffer!
    @buffer.replace ''
  end
  
  def jump(pos)
    @instruction_pointer = pos
  end
  
end

end