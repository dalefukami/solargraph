# frozen_string_literal: true

require 'open3'

module Solargraph
  module LanguageServer
    module Message
      module TextDocument
        class CodeAction < Base
          def process
            # XXX: not everything can have this code action....what is our determination?
            # XXX: single line...more than one character?....full "words", eg: " 1 " and "thing.stuff"?

            fileUri = params['textDocument']['uri']
            original = host.read_text(fileUri)
            line = original.split("\n")[params['range']['start']['line']]
            content = line[params['range']['start']['character']...params['range']['end']['character']]

            return set_result([]) unless is_whole_word?(line, params['range']['start']['character'], params['range']['end']['character'])

            # Ensure we only capture "whole words" and not leading trailing whitespace
            trimmed_content = content.strip
            start_chars_removed = 0
            while content[start_chars_removed] != trimmed_content[0]
              start_chars_removed += 1
            end
            end_chars_removed = content.length - trimmed_content.length - start_chars_removed

            content = line[(params['range']['start']['character']+start_chars_removed)...(params['range']['end']['character']-end_chars_removed)]

            # XXX: Clone range instead?
            selectionRange = params['range'] # XXX: trim the spaces around the selection?
            selectionRange['start']['character'] += start_chars_removed
            selectionRange['end']['character'] -= end_chars_removed
            selectionLine = params['range']['start']['line']
            # XXX: match indentation
            newVarRange = {
              start: { line: selectionLine, character: 0 },
              end: { line: selectionLine, character: 0 }
            }
            set_result(
              [
                {
                  title: "Extract Variable",
                  kind: "refactor",
                  # command: "extractVariable" # This requires the extension to register the command?
                  edit: {
                    changes: {
                      "#{fileUri}": [
                        {
                          range: newVarRange,
                          newText: "newvar = #{trimmed_content}\n"
                        },
                        {
                          range: selectionRange,
                          newText: "newvar"
                        }
                      ]
                    }
                  }
                }
              ]
            )
          end

          def is_whole_word?(line, start_char, end_char)
            content = line[start_char...end_char]

            trimmed_content = content.strip
            start_chars_removed = 0
            while content[start_chars_removed] != trimmed_content[0]
              start_chars_removed += 1
            end
            end_chars_removed = content.length - trimmed_content.length - start_chars_removed

            true_start = params['range']['start']['character'] + start_chars_removed
            true_end = params['range']['end']['character'] - end_chars_removed
            content = line[true_start...true_end]

            # Hack... if we remove all non-variable-ish things from the surrounding characters and
            # it matches the content we're trying to extract then we have "whole words"
            # We should do real token parsing, etc.
            extended_selection = line[(true_start-1)..true_end].gsub(/(^[^a-z'"_])|([^a-z'"_]$)/,'')
            return content == extended_selection
          end
        end
      end
    end
  end
end