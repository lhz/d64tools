module D64
  class Directory
    attr_reader :image, :sectors, :entries

    SECTOR_INTERLEAVE = 3

    def initialize(image)
      @image = image
      @sectors = []
      @entries = []
      add_sector
    end

    def <<(entry)
      add_sector if sector.nil? || sector_full?
      set_entry 0x02, entry.type_value
      set_entry 0x03, [entry.first_block.track, entry.first_block.sector]
      set_entry 0x05, entry.padded_name
      set_entry 0x1E, [entry.sectors.size % 256, entry.sectors.size / 256]
      sector.commit
      @entries << entry
    end

    def dump
      sectors.each &:dump
    end

    private

    def sector
      sectors.last
    end
  
    def sector_full?
      entries.size > 0 && entries.size % 8 == 0
    end

    def sector_offset
      32 * (entries.size % 8)
    end

    def add_sector
      block = image.bam.next_free_dir_block
      new_sector = Sector.new(image, block, empty_content)
      if sector
        sector.link_to new_sector
        sector.commit
      end
      @sectors << new_sector
    end

    def empty_content
      [0, 255] + [0] * 254
    end

    def set_entry(offset, value)
      sector[sector_offset + offset] = value
    end
  end
end
