class Instruction; end

class Consumer < Instruction
  
  def initialize(count)
    @count, @buffer = count, ""
  end
  
  def call(connection)
    return_value = nil
    if @buffer.length < @count
      @buffer << connection.readpartial(@count - @buffer.length)
    else
      return_value = [@buffer, :done]
    end
    return_value
  end
  
end

class PartialReaderDSL
  
  def self.protocol(&blk)
    current_instance = new
    blk.call(current_instance)
    current_instance
  end
  
  def initialize
    @buffer = ""
    @instruction_sequence = []
    @current_instruction_pointer = 0
    @return_stack = []
  end
  
  def current_instruction
    @instruction_sequence[@current_instruction_pointer]
  end
  
  def call(connection)
    if (current_instr = current_instruction).nil?
      return @return_stack
    end
    res = current_instr.call(connection)
    return if res.empty?
    @instruction_pointer += 1
  end
  
  def consume(count)
    @instruction_sequence << Consumer.new(count)
  end
  
  def buffer_transform(&blk)
    @return_stack << blk.call(self)
  end
  
  def splice(*instructions)
    current_instruction = @insturction_sequence[@current_instruction_pointer]
    instructions.unshift(current_instruction)
    @instruction_sequence[@current_instruction_pointer] = instructions
    @instruction_sequence.flatten!
  end
    
end