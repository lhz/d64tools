module D64
  class Sector
    attr_reader :image, :block, :bytes

    def initialize(image, block, bytes)
      @image = image
      @block = block
      @bytes = bytes
    end

    def []=(offset, value)
      value = Array(value)
      @bytes[offset, value.size] = value
    end

    def to_s
      "<D64::Sector:#{object_id.to_s(16)} t=#{@block.track} s=#{@block.sector}>"
    end

    def pos
      '[%02X:%02X]' % [block.track, block.sector]
    end

    def name_pos
      '[%s %02X:%02X]' % [image.name, block.track, block.sector]
    end
    
    def next
      tn, sn = @bytes[0, 2]
      image.sector([tn, sn]) if tn > 0
    end

    def chain
      list = [self]
      while list.last.next
        list << list.last.next
      end
      list
    end

    def copy_content_from(other, opts = {})
      logger.debug "Copying content from #{other.name_pos} to #{name_pos}."
      first = (opts[:include_link] ? 0 : 2)
      if block.track == 18 && block.sector == 0 && !opts[:include_bam]
        @bytes[first..3] = other.bytes[first..3]
        @bytes[0x90..-1] = other.bytes[0x90..-1]
      else
        @bytes[first..-1] = other.bytes[first..-1]
      end
      commit
    end

    def link_to(other, opts = {})
      logger.debug "Linking #{name_pos} to #{other.name_pos}."
      @bytes[0, 2] = [other.block.track, other.block.sector]
      commit
    end

    def end_chain
      @bytes[0, 2] = [0, 255]
      commit
    end

    def commit
      image.commit_sector(self)
    end

    def dump
      puts 8.times.map { |i|
        ('%05X  %s ' % [Image.offset(block) + 32 * i, pos]) <<
          (' %02X' * 32 % @bytes[32 * i, 32]) <<
          (' %32s' % bytes_string(@bytes[32 * i, 32]))
      }.join("\n")
    end

    private

    def bytes_string(bytes)
      bytes.map { |b|
        case b
        when 0x20..0x7F then b.chr
        else
          '.'
        end
      }.join
    end

    def logger
      D64.logger
    end
  end
end
