describe Solargraph::LanguageServer::Message::TextDocument::Rename do
  it "renames a symbol" do
    host = Solargraph::LanguageServer::Host.new
    host.start
    host.open('file:///file.rb', %(
      class Foo
      end
      foo = Foo.new
    ), 1)
    rename = Solargraph::LanguageServer::Message::TextDocument::Rename.new(host, {
      'id' => 1,
      'method' => 'textDocument/rename',
      'params' => {
        'textDocument' => {
          'uri' => 'file:///file.rb'
        },
        'position' => {
          'line' => 1,
          'character' => 12
        },
        'newName' => 'Bar'
      }
    })
    rename.process
    expect(rename.result[:changes]['file:///file.rb'].length).to eq(2)
  end

  it "renames a variable" do
    host = Solargraph::LanguageServer::Host.new
    host.start
    host.open('file:///file.rb', %(
      class Foo
        def method()
          var_one = 'things'
          puts var_one
        end
      end
    ), 1)
    rename = Solargraph::LanguageServer::Message::TextDocument::Rename.new(host, {
      'id' => 1,
      'method' => 'textDocument/rename',
      'params' => {
        'textDocument' => {
          'uri' => 'file:///file.rb'
        },
        'position' => {
          'line' => 3,
          'character' => 10
        },
        'newName' => 'bar_var'
      }
    })
    rename.process
    expect(rename.result[:changes]['file:///file.rb'].length).to eq(2)
    file_changes = rename.result[:changes]['file:///file.rb']
    expect(file_changes.first[:range][:start][:line]).to eq(3)
    expect(file_changes.first[:range][:start][:character]).to eq(10)
    expect(file_changes.first[:range][:end][:line]).to eq(3)
    expect(file_changes.first[:range][:end][:character]).to eq(17)
    expect(file_changes.first[:newText]).to eq("bar_var")

    expect(file_changes[1][:range][:start][:line]).to eq(4)
    expect(file_changes[1][:range][:start][:character]).to eq(15)
    expect(file_changes[1][:range][:end][:line]).to eq(4)
    expect(file_changes[1][:range][:end][:character]).to eq(22)
    expect(file_changes[1][:newText]).to eq("bar_var")
  end
end
