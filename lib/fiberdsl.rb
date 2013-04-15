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
        puts "Blocing read."; @connection.read(count)
      else
        puts "Non-blocking read."; @connection.read_nonblock(count)
      end
    end

    def consume(count = nil, &blk)
      @count = count || @return_stack.pop
      puts "Trying to consume #{@count} bytes."
      while (delta = @count - @buffer.length) > 0
        begin
          @buffer << read(delta)
        rescue Errno::EAGAIN
          puts "Yielding."; Fiber.yield
        rescue Exception => e
          puts e; raise
        end
      end
      puts "Consume call done."
      (@return_stack << blk.call(@buffer); empty_buffer!) if blk
    end

    def empty_buffer!; @buffer.replace ''; end

    def buffer_transform(&blk); blk.call(self); empty_buffer! end

    def call(conn)
      if @blocking
        @fiber.resume(conn)
        return @return_stack
      end
      puts "Checking fiber state to decide what to do."
      if @fiber.alive?
        puts "Fiber not done."; @fiber.resume(conn); nil
      else
        puts "Fiber done."; @return_stack
      end
    end

  end

end
