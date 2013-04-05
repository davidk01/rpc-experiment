class HeartbeatCallback
  
  def initialize(beat, wipe)
    checker = lambda { |ctx| message_checker(ctx) }
    @wipe = wipe; @beat = beat; @machine = PartialReaderDSL::FiberReaderMachine.protocol do
      catch(:unrecognized_message) { loop { consume(2); buffer_transform(&checker) } }
    end
  end
  
  def message_checker(ctx)
    if ctx.buffer == "OK"
      @beat.call
    else
      $logger.error "Did not recognize heartbeat message: #{ctx.buffer}."
      @wipe.call; throw :unrecognized_message
    end
  end

  def call(monitor)
    begin
      @machine.call(monitor.io)
    rescue EOFError
      $logger.error "EOFError from #{monitor.io.remote_address}."
      @wipe.call
    end
  end
  
end
