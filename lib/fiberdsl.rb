require 'fiber'

module PartialReaderDSL

  class FiberReaderMachine
    
    def self.protocol(blocking = false, &blk)
      (current_instance = new).singleton_class.class_eval { define_method(:resumer, &blk) }
      current_instance.blocking = blocking; current_instance
    end

    attr_reader :return_stack, :buffer

    def initialize
      @buffer, @return_stack, @blocking = "", [], false
      @fiber = Fiber.new { |c| @connection = c; resumer }
    end

    def blocking=(bool); @blocking = bool; end

    def reset
      @fiber = Fiber.new { |c| @connection = c; resumer }
    end

    def read(count)
      if @blocking
        @connection.read(count)
      else
        @connection.read_nonblock(count)
      end
    end

    def consume(count = nil, &blk)
      @count = count || @return_stack.pop
      while (delta = @count - @buffer.length) > 0
        begin
          @buffer << read(delta)
        rescue Errno::EAGAIN
          Fiber.yield
        rescue Exception => e
          puts e.class; puts e; raise
        end
      end
      (@return_stack << blk.call(@buffer); empty_buffer!) if blk
    end

    def empty_buffer!; @buffer.replace ''; end

    def buffer_transform(&blk); blk.call(self); empty_buffer! end

    def call(conn)
      if @blocking
        @fiber.resume(conn)
        return @return_stack
      end
      if @fiber.alive?
        @fiber.resume(conn); nil
      else
        @return_stack
      end
    end

  end

end
