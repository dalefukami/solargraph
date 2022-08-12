describe Solargraph::LanguageServer::Message::TextDocument::CodeAction do
  context 'when checking for variable extraction' do
    it 'extracts variable' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
First line
some code 'here' 
Last Line
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>1, "character"=>10}, "end"=>{"line"=>1, "character"=>16}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
      result = message.process
      expect(result.first[:kind]).to eq("refactor.extract.variable")
      expect(result.first[:title]).to eq("Extract Variable")
      file_changes = result.first[:edit][:changes]["test.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
      expect(file_changes.first[:range][:start][:line]).to eq(1)
      expect(file_changes.first[:range][:end][:line]).to eq(1)
      expect(file_changes.first[:newText]).to eq("newvar = 'here'\n")

      expect(file_changes[1][:range]['start']['line']).to eq(1)
      expect(file_changes[1][:range]['start']['character']).to eq(10)
      expect(file_changes[1][:range]['end']['line']).to eq(1)
      expect(file_changes[1][:range]['end']['character']).to eq(16)
      expect(file_changes[1][:newText]).to eq("newvar")
    end

    it 'encompasses whole selection' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
if 'some string' && 'other string'
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>0, "character"=>3}, "end"=>{"line"=>0, "character"=>16}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
      result = message.process
      file_changes = result.first[:edit][:changes]["test.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
      expect(file_changes.first[:range][:start][:line]).to eq(0)
      expect(file_changes.first[:range][:end][:line]).to eq(0)
      expect(file_changes.first[:newText]).to eq("newvar = 'some string'\n")

      range = file_changes[1][:range]
      expect(range['start']['line']).to eq(0)
      expect(range['start']['character']).to eq(3)
      expect(range['end']['line']).to eq(0)
      expect(range['end']['character']).to eq(16)
      expect(file_changes[1][:newText]).to eq("newvar")
    end

    it 'trims selection' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
if 'some string' && 'other string'
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>0, "character"=>2}, "end"=>{"line"=>0, "character"=>17}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
      result = message.process
      file_changes = result.first[:edit][:changes]["test.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
      expect(file_changes.first[:range][:start][:line]).to eq(0)
      expect(file_changes.first[:range][:end][:line]).to eq(0)
      expect(file_changes.first[:newText]).to eq("newvar = 'some string'\n")

      range = file_changes[1][:range]
      expect(range['start']['line']).to eq(0)
      expect(range['start']['character']).to eq(3)
      expect(range['end']['line']).to eq(0)
      expect(range['end']['character']).to eq(16)
      expect(file_changes[1][:newText]).to eq("newvar")
    end

    it 'does not return action if whole word not selected' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
if 'some string' && 'other string'
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>0, "character"=>5}, "end"=>{"line"=>0, "character"=>6}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)

      result = message.process

      expect(result).to eq([])
    end

    it 'considers non-variable things as word surrounders' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
if ('some string') && 'other string'
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>0, "character"=>4}, "end"=>{"line"=>0, "character"=>17}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)

      result = message.process

      expect(result.length).to eq(1)
    end

    it 'matches indentation of selected line' do
      host = double(:Host, definitions_at: [], read_text: <<-CODE
  if 'some string' && 'other string'
CODE
      )
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'test.rb' },
          'range'=> { "start"=>{"line"=>0, "character"=>5}, "end"=>{"line"=>0, "character"=>18}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)

      result = message.process

      file_changes = result.first[:edit][:changes]["test.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
      expect(file_changes.first[:newText]).to eq("  newvar = 'some string'\n")
    end
  end

  context 'when checking for variable inlining' do
    it 'inlines variable' do
      host = Solargraph::LanguageServer::Host.new
      host.start
      host.open('file:///file.rb', %(
        def method()
          var_one = 'some value'
          puts var_one
        end
      ), 1)
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'file:///file.rb' },
          'range'=> { "start"=>{"line"=>2, "character"=>10}, "end"=>{"line"=>2, "character"=>11}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
      result = message.process
      inline = result.find {|r| r[:kind] == "refactor.inline.variable"}

      expect(inline[:kind]).to eq("refactor.inline.variable")
      expect(inline[:title]).to eq("Inline Variable")
      file_changes = inline[:edit][:changes]["file:///file.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}

      expect(file_changes.first[:range][:start][:line]).to eq(3)
      expect(file_changes.first[:range][:start][:character]).to eq(15)
      expect(file_changes.first[:range][:end][:line]).to eq(3)
      expect(file_changes.first[:range][:end][:character]).to eq(22)
      expect(file_changes.first[:newText]).to eq("'some value'")

      expect(file_changes[1][:range][:start][:line]).to eq(2)
      expect(file_changes[1][:range][:start][:character]).to eq(0)
      expect(file_changes[1][:range][:end][:line]).to eq(3)
      expect(file_changes[1][:range][:end][:character]).to eq(0)
      expect(file_changes[1][:newText]).to eq("")
    end

    it 'inlines value from variable definition when cursor is on usage line' do
      host = Solargraph::LanguageServer::Host.new
      host.start
      host.open('file:///file.rb', %(
        def method()
          var_one = 'some value'
          puts var_one
        end
      ), 1)
      request = {
        'params' => {
          'textDocument' => { 'uri' => 'file:///file.rb' },
          'range'=> { "start"=>{"line"=>3, "character"=>19}, "end"=>{"line"=>3, "character"=>19}}
        }
      }
      message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
      result = message.process
      inline = result.find {|r| r[:kind] == "refactor.inline.variable"}

      file_changes = inline[:edit][:changes]["file:///file.rb".to_sym]
      file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
      expect(file_changes.first[:range][:start][:line]).to eq(3)
      expect(file_changes.first[:range][:start][:character]).to eq(15)
      expect(file_changes.first[:range][:end][:line]).to eq(3)
      expect(file_changes.first[:range][:end][:character]).to eq(22)
      expect(file_changes.first[:newText]).to eq("'some value'")
    end
  end
end
