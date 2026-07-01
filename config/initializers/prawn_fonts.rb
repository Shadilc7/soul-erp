require 'prawn'

module PrawnFontSetup
  def initialize(options = {}, &block)
    # 1. Call super without the block to initialize the document structure first
    super(options) 

    # 2. Setup our custom Unicode fonts
    roboto_regular = Rails.root.join("app", "assets", "fonts", "Roboto-Regular.ttf").to_s
    roboto_bold = Rails.root.join("app", "assets", "fonts", "Roboto-Bold.ttf").to_s
    roboto_italic = Rails.root.join("app", "assets", "fonts", "Roboto-Italic.ttf").to_s
    malayalam_regular = Rails.root.join("app", "assets", "fonts", "NotoSansMalayalam-Regular.ttf").to_s
    arabic_regular = Rails.root.join("app", "assets", "fonts", "NotoSansArabic-Regular.ttf").to_s
    hindi_regular = Rails.root.join("app", "assets", "fonts", "NotoSansDevanagari-Regular.ttf").to_s

    fonts_to_update = {}

    if File.exist?(roboto_regular)
      fonts_to_update["Roboto"] = {
        normal: roboto_regular,
        bold: File.exist?(roboto_bold) ? roboto_bold : roboto_regular,
        italic: File.exist?(roboto_italic) ? roboto_italic : roboto_regular,
        bold_italic: File.exist?(roboto_bold) ? roboto_bold : roboto_regular
      }
    end

    if File.exist?(malayalam_regular)
      fonts_to_update["Malayalam"] = {
        normal: malayalam_regular,
        bold: malayalam_regular,
        italic: malayalam_regular,
        bold_italic: malayalam_regular
      }
    end

    if File.exist?(arabic_regular)
      fonts_to_update["Arabic"] = {
        normal: arabic_regular,
        bold: arabic_regular,
        italic: arabic_regular,
        bold_italic: arabic_regular
      }
    end

    if File.exist?(hindi_regular)
      fonts_to_update["Devanagari"] = {
        normal: hindi_regular,
        bold: hindi_regular,
        italic: hindi_regular,
        bold_italic: hindi_regular
      }
    end

    unless fonts_to_update.empty?
      self.font_families.update(fonts_to_update)
      self.font "Roboto" if fonts_to_update.key?("Roboto")
      
      fallbacks = ["Malayalam", "Arabic", "Devanagari"].select { |f| fonts_to_update.key?(f) }
      self.fallback_fonts(fallbacks) unless fallbacks.empty?
    end

    # 3. Now execute the block if one was passed. 
    # (By doing this after font setup, any pdf.text inside the block works correctly with Unicode).
    if block
      block.arity < 1 ? instance_eval(&block) : block.call(self)
    end
  end
end

Prawn::Document.prepend(PrawnFontSetup)
