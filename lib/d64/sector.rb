module D64
  class Sector
    attr_reader :image, :block, :bytes

    def initialize(image, block, bytes)
      @image = image
      @block = block
      @bytes = bytes
    end

    def to_s
      "<D64::Sector:#{object_id.to_s(16)} t=#{@block.track} s=#{@block.sector}>"
    end

    def pos
      '[%02d:%02d]' % [block.track, block.sector]
    end

    def name_pos
      '[%s %02d:%02d]' % [image.name, block.track, block.sector]
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
      puts "Copying content from #{other.name_pos} to #{name_pos}." if ENV['DEBUG']
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
      puts "Linking #{name_pos} to #{other.name_pos}." if ENV['DEBUG']
      @bytes[0, 2] = [other.block.track, other.block.sector]
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
  end
end
