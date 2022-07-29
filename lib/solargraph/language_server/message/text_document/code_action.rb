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

            selectionRange = params['range'] # XXX: trim the spaces around the selection?
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
                          newText: "newvar = #{content}\n"
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
        end
      end
    end
  end
end


# [DEBUG] {"jsonrpc"=>"2.0", "id"=>25, "method"=>"textDocument/codeAction", "params"=>{"textDocument"=>{"uri"=>"file:///data2/projects/app-shift-dealer/spec/services/fieldops/appointments/cancel_intent_service_spec.rb"}, "range"=>{"start"=>{"line"=>29, "character"=>13}, "end"=>{"line"=>29, "character"=>13}}, "context"=>{"diagnostics"=>[]}}}