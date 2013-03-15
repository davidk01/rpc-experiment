module PartialReaderDSL

class Instruction
  # advise the partial reader machine how to proceed based on the status
  # of the connection
  def return_value(connection)
  end
end

class Consumer < Instruction
  
  def initialize(count, &blk)
    @count, @blk = count, blk
  end
  
  def call_block(context)
    res = @blk.call(context.buffer); context.empty_buffer!; context.return res
  end
  
  def call(context, connection)
    if (delta = (@count ||= context.return_stack.pop) - context.buffer.length) > 0
      begin
        context.buffer << connection.read_nonblock(delta)
      rescue Errno::EAGAIN
        return :call_again
      end
      if context.buffer.length == @count
        call_block(context) if @blk
        return :done
      end
    end
    return :call_again
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
    (current_instance = new).singleton_class.class_eval { define_method(:instantiator, &blk) }
    current_instance.instantiator; current_instance
  end
  
  attr_reader :buffer, :return_stack, :instruction_pointer
  
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
      call(connection) # this can potentially block select loop
    when :delay_call
      @instruction_pointer += 1
    when :call_again
    else
      throw :unknown_return_code, status
    end
    return :not_done
  end
  
  def consume(count = nil, &blk)
    consumer = Consumer.new(count, &blk); @instruction_sequence << consumer; consumer
  end
  
  def return(value)
    @return_stack << value
  end
  
  def buffer_transform(&blk)
    transformer = BufferTransform.new(&blk); @instruction_sequence << transformer; transformer
  end
  
  def empty_buffer!
    @buffer.replace ''
  end
  
  def jump(pos)
    @instruction_pointer = pos
  end
  
end

end
