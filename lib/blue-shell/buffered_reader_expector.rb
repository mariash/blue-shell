module BlueShell
  class BufferedReaderExpector
    attr_reader :output

    def initialize(out, debug = false)
      @out = out
      @debug = debug
      @unused = ""
      @output = ""
    end

    def expect(pattern)
      case pattern
        when String
          pattern = Regexp.new(Regexp.quote(pattern))
        when Regexp
        else
          raise TypeError, "unsupported pattern class: #{pattern.class}"
      end

      result, buffer = read_pipe(BlueShell.timeout, pattern)

      @output << buffer

      result
    end

    def read_to_end
      _, buffer = read_pipe(0.01)
      @output << buffer
    end

    private

    def read_pipe(timeout, pattern = nil)
      buffer = ""
      result = nil
      position = 0
      @unused ||= ""

      while true
        if !@unused.empty?
          c = @unused.slice!(0).chr
        elsif output_ended?(timeout)
          @unused = buffer
          break
        else
          c = @out.getc.chr
        end

        STDOUT.putc c if @debug

        # wear your flip flops
        unless (c == "\e") .. (c == "m")
          if c == "\b"
            if position > 0 && buffer[position - 1] && buffer[position - 1].chr != "\n"
              position -= 1
            end
          else
            if buffer.size > position
              buffer[position] = c
            else
              buffer << c
            end

            position += 1
          end
        end

        if pattern && matches = pattern.match(buffer)
          result = [buffer, *matches.to_a[1..-1]]
          break
        end
      end

      return result, buffer
    end

    def output_ended?(timeout)
      (@out.is_a?(IO) && !IO.select([@out], nil, nil, timeout)) || @out.eof?
    end
  end
end
