require 'English'
class AgentBots::TextSegmentationService
  def initialize(limit = 300, min_size = 50)
    @limit = limit <= 0 ? 300 : limit
    @min_size = min_size <= 0 ? 50 : min_size
  end

  def segment_text(text)
    return [] if text.blank?

    # Verifica se o texto já está no formato de mídia pré-formatado
    return [text] if preformatted_media?(text)

    # Verifica se o texto contém blocos de código
    code_blocks = extract_code_blocks(text)
    return process_text_with_code_blocks(text, code_blocks) if code_blocks.any?

    # Verifica se o texto contém elementos de mídia
    return process_media_elements(text) if media?(text)

    # Se não contém mídia, verifica o tamanho
    if text.length <= @min_size
      return valid_segment?(text) ? [text] : []
    end

    # Divide o texto em parágrafos
    paragraphs = text.split("\n\n")

    # Se o texto não contém parágrafos, trata como um único parágrafo
    return split_paragraph_into_sentences(paragraphs[0]) if paragraphs.length == 1

    segments = []

    # Processa cada parágrafo separadamente
    paragraphs.each do |paragraph|
      paragraph = paragraph.strip
      next if paragraph.empty?

      if paragraph.length <= @limit
        segments << paragraph
      else
        sentences = split_paragraph_into_sentences(paragraph)
        segments.concat(sentences)
      end
    end

    # Combina segmentos pequenos respeitando a estrutura de parágrafos
    segments = combine_segments_preserving_line_breaks(segments)

    # Filtra segmentos inválidos
    segments.filter { |segment| valid_segment?(segment) }
  end

  private

  def preformatted_media?(text)
    text.match?(/^(audio|image|video|document)::(.*)@@(.+)$/)
  end

  def media?(text)
    # Expressão regular para verificar se tem mídia
    # Regex to check for media elements (images, links, URLs)
    media_regex = %r{
      (?:(!?)\[([^\]]*)\]\(([^)]+)\))|         # Markdown images/links
      (?:\[([^\]:]*):?\s*(https?://[^\s\]]+)\])|  # Bracket links
      (?:(https?://|www\.)[^\s\n\]]+)|         # URLs
      (?:[^\s\n\]]+\.(com|org|net|edu|gov|io|co)[^\s\n\]]*) # Domain extensions
    }x
    text.match?(media_regex)
  end

  def extract_code_blocks(text)
    code_block_regex = /```[\w]*\n[\s\S]*?```/
    matches = []
    text.scan(code_block_regex) do |match|
      start_pos = text.index(match)
      end_pos = start_pos + match.length
      matches << { start: start_pos, end: end_pos, content: match }
    end
    matches
  end

  def process_text_with_code_blocks(text, code_blocks)
    segments = []
    last_index = 0

    code_blocks.each do |block|
      # Adiciona o texto antes do bloco de código
      if block[:start] > last_index
        text_before = text[last_index...block[:start]].strip
        segments << text_before unless text_before.empty?
      end

      # Adiciona o bloco de código como um segmento único
      segments << block[:content]
      last_index = block[:end]
    end

    # Adiciona o texto restante após o último bloco de código
    if last_index < text.length
      text_after = text[last_index..].strip
      segments << text_after unless text_after.empty?
    end

    # Processa cada segmento que não é um bloco de código
    final_segments = []
    segments.each do |segment|
      if segment.start_with?('```')
        final_segments << segment
      else
        processed_segments = segment_text(segment)
        final_segments.concat(processed_segments)
      end
    end

    final_segments
  end

  def process_media_elements(text)
    return [text] if preformatted_media?(text)

    # Regex for media elements processing
    media_regex = %r{
      (?:(!?)\[([^\]]*)\]\(([^)]+)\))|         # Markdown images/links
      (?:\[([^\]:]*):?\s*(https?://[^\s\]]+)\])|  # Bracket links
      (?:(https?://|www\.)[^\s\n\]]+)|         # URLs
      (?:[^\s\n\]]+\.(com|org|net|edu|gov|io|co)[^\s\n\]]*) # Domain extensions
    }x
    paragraphs = text.split("\n\n")
    segments = []

    paragraphs.each do |paragraph|
      paragraph = paragraph.strip
      next if paragraph.empty?

      next segments << paragraph if preformatted_media?(paragraph)

      unless media?(paragraph)
        # Se não contém mídia, processa como texto normal
        if paragraph.length > @limit
          sentences = split_paragraph_into_sentences(paragraph)
          segments.concat(sentences)
        else
          segments << paragraph
        end
        next
      end

      # Verifica se tem mídia real (não apenas URLs de texto)
      has_actual_media = false
      paragraph.scan(media_regex) do |match|
        full_match = ::Regexp.last_match(0)
        is_image = match[0] == '!'
        url = match[2] || match[4] || full_match
        media_type = determine_media_type(url)

        if is_image || media_type != 'text'
          has_actual_media = true
          break
        end
      end

      unless has_actual_media
        # Se contém apenas URLs regulares, processa como texto normal
        if paragraph.length > @limit
          sentences = split_paragraph_into_sentences(paragraph)
          segments.concat(sentences)
        else
          segments << paragraph
        end
        next
      end

      last_index = 0

      # Processa todos os elementos de mídia no parágrafo
      paragraph.scan(media_regex) do |match|
        match_start = paragraph.index(::Regexp.last_match(0), last_index)
        match_end = match_start + ::Regexp.last_match(0).length

        # Adiciona o texto antes da mídia como um segmento
        if match_start > last_index
          text_before = paragraph[last_index...match_start].strip
          if !text_before.empty? && valid_segment?(text_before)
            if text_before.length > @limit
              sentences = split_paragraph_into_sentences(text_before)
              segments.concat(sentences)
            else
              segments << text_before
            end
          end
        end

        # Extrai a mídia e adiciona como um segmento separado
        full_match = ::Regexp.last_match(0)
        is_image = match[0] == '!'
        alt_text = match[1] || match[3] || ''
        url = match[2] || match[4] || full_match
        media_type = determine_media_type(url)

        # Se for uma imagem ou outro tipo de mídia, trata como mídia
        if is_image || media_type != 'text'
          media_segment = "#{media_type}::#{alt_text}@@#{url}"
          segments << media_segment
        end

        last_index = match_end
      end

      # Adiciona o texto restante do parágrafo
      next unless last_index < paragraph.length

      text_after = paragraph[last_index..].strip
      next if text_after.empty?

      # Remove pontuação inicial se seguir mídia
      if text_after.match?(/^[.!?,:; ]/)
        clean_text = text_after.gsub(/^[.!?,:; ]+/, '')
        text_after = clean_text unless clean_text.empty?
      end

      if valid_segment?(text_after)
        if text_after.length > @limit
          sentences = split_paragraph_into_sentences(text_after)
          segments.concat(sentences)
        else
          segments << text_after
        end
      end
    end

    # Remove segmentos vazios e normaliza
    segments.filter { |segment| !segment.strip.empty? && valid_segment?(segment) }
  end

  def split_paragraph_into_sentences(paragraph)
    return [paragraph] if paragraph.length <= @limit

    # Verifica se contém listas numeradas - se sim, mantém como uma frase
    return [paragraph] if paragraph.match?(/\n\d+\./)

    sentences = split_into_sentences(paragraph)
    return [] if sentences.empty?

    segments = []
    current_segment = ''

    sentences.each do |sentence|
      sentence = sentence.strip
      next if sentence.empty?

      test_segment = current_segment.empty? ? sentence : "#{current_segment} #{sentence}"

      if test_segment.length <= @limit
        current_segment = test_segment
      else
        if current_segment.empty?
          # A frase sozinha é maior que o limite - mantém intacta
        else
          segments << current_segment
        end
        current_segment = sentence
        current_segment = sentence
      end
    end

    segments << current_segment unless current_segment.empty?
    segments.filter { |segment| valid_segment?(segment) }
  end

  def split_into_sentences(text)
    # Verifica se contém listas numeradas
    return [text] if text.match?(/\n\d+\./)

    # Regex para dividir em finais de frase: . ! ? seguidos de espaço
    sentence_regex = /([.!?]+)(\s+)/
    matches = []
    text.scan(sentence_regex) { matches << [$LAST_MATCH_INFO.begin(0), $LAST_MATCH_INFO.end(0)] }

    return [text.strip] if matches.empty?

    sentences = []
    last_end = 0

    matches.each do |match_start, match_end|
      # Verifica se pode ser uma lista numerada
      before_start = [match_start - 5, 0].max
      before_period = text[before_start...match_start]

      # Pula se parece uma lista numerada
      next if before_period.match?(/\b\d+$/)

      sentence = text[last_end...match_end].strip
      sentences << sentence unless sentence.empty?
      last_end = match_end
    end

    # Adiciona texto restante após a última fronteira de frase
    if last_end < text.length
      remaining = text[last_end..].strip
      sentences << remaining unless remaining.empty?
    end

    sentences.empty? ? [text.strip] : sentences
  end

  def combine_segments_preserving_line_breaks(segments)
    return segments if segments.length <= 1

    result = []
    current = segments[0]

    (1...segments.length).each do |i|
      combined_size = current.length + 2 + segments[i].length # +2 para "\n\n"

      if current.length < @min_size && combined_size <= @limit
        current = current.empty? ? segments[i] : "#{current}\n\n#{segments[i]}"
      else
        result << current if !current.empty? && valid_segment?(current)
        current = segments[i]
      end
    end

    result << current if !current.empty? && valid_segment?(current)
    result
  end

  # Delegates to the shared AgentBots::MediaTypeDetector (single source of truth).
  # Now also matches extensions followed by a query string / fragment
  # (e.g. ".mp4?v=1"), which the previous anchored regex ($) missed.
  def determine_media_type(url)
    AgentBots::MediaTypeDetector.detect(url)
  end

  def valid_segment?(segment)
    trimmed = segment.strip
    return false if trimmed.empty?
    return false if trimmed.delete('.').empty?

    true
  end
end
