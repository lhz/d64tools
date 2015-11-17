module D64
  class Entry
    attr_reader :image, :name, :type, :sectors

    TYPES = [:del, :seq, :prg, :usr, :rel]

    def initialize(image, name, type)
      fail "Invalid entry type: #{type}" unless TYPES.include?(type)
      @name = name
      @type = type
      @image = image
      @sectors = []
    end

    def padded_name
      name.bytes + [0xA0] * (16 - name.bytes.size)
    end

    def type_value
      0x80 + TYPES.index(type)
    end

    def store(content)
      sector = image.last_file_sector
      block = sector.block if sector
      content.each_slice(254) do |bytes|
        bytes << 255 until bytes.size == 254
        block = image.bam.allocate_with_interleave(block, image.interleave) or
          fail "No free blocks, disk full!"
        new_sector = Sector.new(image, block, [0, 255] + bytes)
        new_sector.commit
        if sector
          sector.link_to new_sector
          sector.commit
        end
        sector = new_sector
        @sectors << sector
      end
      image.last_file_sector = sector
      image.directory << self
      image.bam.commit
    end

    def first_block
      sectors.first.block
    end

    def dump
      sectors.each &:dump
    end
  end
end
