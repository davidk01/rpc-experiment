module PartialReaderDSL

  class FiberReaderMachine
    
    def self.protocol(&blk)
      (current_instance = new).singleton_class.class_eval do 
        define_method(:resumer, &blk)
      end
      current_instance
    end

    attr_reader :connection, :return_stack, :buffer

    def initialize
      @buffer, @return_stack = "", []
      @fiber = Fiber.new { |c| @connection = c; resumer; @return_stack }
    end

    def consume(count = nil, &blk)
      @count = count || @return_stack.pop
      while (delta = @count - @buffer.length) > 0
        begin
          @buffer << @connection.read_nonblock(delta)
        rescue Errno::EAGAIN
          Fiber.yield
        rescue Exception => e
          $logger.error e; raise
        end
      end
      (@return_stack << blk.call(@buffer); empty_buffer!) if blk
      nil
    end

    def empty_buffer!
      @buffer.replace ''
    end

    def buffer_transform(&blk)
      blk.call(self); empty_buffer!; nil
    end

    def call(connection)
      $logger.debug "Resuming fiber."
      @fiber.resume(connection)
    end
  end

end