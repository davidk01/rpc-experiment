class HeartbeatCallback
  
  def initialize(beat, wipe)
    @wipe = wipe; @machine = PartialReaderDSL::FiberReaderMachine.protocol do
      message_checker = lambda do |ctx|
        if ctx.buffer == "OK"
          beat.call
        else
          $logger.error "Did not recognize hearbeat message: #{ctx.buffer}."
          wipe.call; throw :unrecognized_message
        end
      end
      catch(:unrecognized_message) { loop { consume(2); buffer_transform(&message_checker) } }
    end
  end
  
  def call(monitor)
    begin
      @machine.call(monitor.io)
    rescue EOFError
      @wipe.call; $logger.error "EOFError from #{monitor.io.remote_address}."
    end
  end
  
end
