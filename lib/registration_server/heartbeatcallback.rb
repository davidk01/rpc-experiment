class HeartbeatCallback
  
  def initialize(beat, wipe)
    checker = lambda { |ctx| message_checker(ctx) }
    @wipe = wipe; @beat = beat; @machine = PartialReaderDSL::FiberReaderMachine.protocol do 
      loop { consume(2); buffer_transform(&checker) }
    end
  end
  
  def message_checker(ctx)
    if ctx.buffer == "OK"
      @beat.call
    else
      puts "Did not recognize heartbeat message: #{ctx.buffer}."
      @wipe.call
    end
  end

  def call(monitor)
    ex = catch(:eoferror) { @machine.call(monitor.io) }
    if ex
      puts "Caught EOFError."; @wipe.call
    end
  end
  
end
