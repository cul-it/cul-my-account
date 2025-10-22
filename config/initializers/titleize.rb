# Following a suggestion from
# https://stackoverflow.com/questions/15078964
# TODO: This needs some work. Some characters in titles are being stripped out - like colons and dashes;
# also, titles that *start* with excluded words may end up lowercased (speculation). As will acronyms.
class String
  def titleize(options = {:exclude => ["and", "or", "the", "to", "a", "but", "at", "of", "on", "in"]})
    exclusions = options[:exclude]

    return ActiveSupport::Inflector.titleize(self) unless exclusions.any?
    self.underscore.humanize.gsub(/\b(?<!['’`])(?!(#{exclusions.join('|')})\b)[a-z]/) { $&.capitalize }
  end
end