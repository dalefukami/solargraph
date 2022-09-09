# frozen_string_literal: true

require 'open3'

module Solargraph
  module LanguageServer
    module Message
      module TextDocument
        class CodeAction < Base
          def process
            results = []
            results.concat(variable_extraction)
            results.concat(variable_inlining)
            set_result(results)
          end

          def variable_inlining()
            range = params['range']

            defs = host.definitions_at(params['textDocument']['uri'], range['start']['line'], range['start']['character'])
            return [] if defs.nil? || defs.length < 1

            definition = defs[0]
            # Only support local variables
            return [] if !definition.variable? || definition.class != ::Solargraph::Pin::LocalVariable

            fileUri = params['textDocument']['uri']
            locs = host.references_from(params['textDocument']['uri'], range['start']['line'], range['start']['character'], strip: true, only: true)
            definition = defs[0]
            original = host.read_text(fileUri)
            var_code = original.split("\n")[definition.location.range.start.line][definition.location.range.start.character...definition.location.range.ending.character]
            match = var_code.match(/#{definition.name} = (.*)$/)
            return [] if match.nil? || match[1].nil?
            value = match[1]

            original_location = locs.find { |l| l.range.start.line == definition.location.range.start.line }
            changes = []
            # There's still a little trickiness as far as nested blocks shadowing variables
            (locs - [original_location])
              .filter { |location| definition.presence.contain?(location.range.start)}
              .each do |location|
              changes.push( { range: location.range.to_hash, newText: value })
            end
            changes.push({
              range: {
                start: { line: definition.location.range.start.line, character: 0 },
                end: { line: definition.location.range.start.line + 1, character: 0 },
              },
              newText: ''
            })

            [
              {
                title: "Inline Variable",
                kind: "refactor.inline.variable",
                edit: {
                  changes: {
                    "#{fileUri}": changes
                  }
                }
              }
            ]
          end

          def variable_extraction()
            fileUri = params['textDocument']['uri']
            original = host.read_text(fileUri)
            line = original.split("\n")[params['range']['start']['line']]
            content = line[params['range']['start']['character']...params['range']['end']['character']]

            return [] unless is_whole_word?(line, params['range']['start']['character'], params['range']['end']['character'])

            # Ensure we only capture "whole words" and not leading trailing whitespace
            trimmed_content = content.strip
            start_chars_removed = 0
            while content[start_chars_removed] != trimmed_content[0]
              start_chars_removed += 1
            end
            end_chars_removed = content.length - trimmed_content.length - start_chars_removed

            content = line[(params['range']['start']['character']+start_chars_removed)...(params['range']['end']['character']-end_chars_removed)]

            # Clone the range instead?
            selectionRange = params['range']
            selectionRange['start']['character'] += start_chars_removed
            selectionRange['end']['character'] -= end_chars_removed
            selectionLine = params['range']['start']['line']

            newVarRange = {
              start: { line: selectionLine, character: 0 },
              end: { line: selectionLine, character: 0 }
            }

            indentation = line.match(/^([ ]*)/)[1].length
            variable_definition = (" " * indentation) + "newvar = #{trimmed_content}\n"

            [
              {
                title: "Extract Variable",
                kind: "refactor.extract.variable",
                # command: "extractVariable" # This requires the vscode extension to know this command exists
                edit: {
                  changes: {
                    "#{fileUri}": [
                      {
                        range: newVarRange,
                        newText: variable_definition
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