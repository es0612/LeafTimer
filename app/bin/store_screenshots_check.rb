# frozen_string_literal: true

# Pure logic for store-screenshots-check (Issue #161).
# Kept free of I/O so bin/test_store_screenshots_check.rb can drive it with
# in-memory byte strings.
module StoreScreenshotsCheck
  PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

  module_function

  # Returns [width, height] from the IHDR chunk, or nil when the bytes are not a PNG.
  def png_size(bytes)
    bytes = bytes.b
    return nil unless bytes.start_with?(PNG_SIGNATURE) && bytes.bytesize >= 24

    bytes[16, 8].unpack('NN')
  end

  # config: parsed screens.json ({ 'devices' => { name => { 'size' => [w, h] } },
  #                               'locales' => [...], 'screens' => [{ 'id' => ... }] })
  # sizes:  { 'ja/iphone/01-timer.png' => [w, h] or nil } for every file found
  def violations(config:, sizes:)
    expected = {}
    config.fetch('locales').each do |locale|
      config.fetch('devices').each do |device, spec|
        config.fetch('screens').each do |screen|
          expected["#{locale}/#{device}/#{screen.fetch('id')}.png"] = spec.fetch('size')
        end
      end
    end

    problems = []
    expected.each do |path, size|
      actual = sizes.fetch(path, :missing)
      if actual == :missing
        problems << "missing: #{path}"
      elsif actual.nil?
        problems << "not a PNG: #{path}"
      elsif actual != size
        problems << "wrong size: #{path} is #{actual.join('x')}, expected #{size.join('x')}"
      end
    end
    (sizes.keys - expected.keys).sort.each { |path| problems << "unexpected: #{path}" }
    problems
  end
end
