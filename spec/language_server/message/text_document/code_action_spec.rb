describe Solargraph::LanguageServer::Message::TextDocument::CodeAction do
  it 'extracts variable' do
    host = double(:Host, read_text: <<-CODE
First line
some code 'here'
Last Line
CODE
    )
    request = {
      'params' => {
        'textDocument' => { 'uri' => 'test.rb' },
        'range'=> { "start"=>{"line"=>1, "character"=>10}, "end"=>{"line"=>1, "character"=>15}}
      }
    }
    message = Solargraph::LanguageServer::Message::TextDocument::CodeAction.new(host, request)
    result = message.process
    expect(result.first[:kind]).to eq("refactor") # XXX: refactor.extract?
    expect(result.first[:title]).to eq("Extract Variable")
    file_changes = result.first[:edit][:changes]["test.rb".to_sym]
    file_changes = file_changes.map{|f| f.transform_keys(&:to_sym)}
    expect(file_changes.first[:range][:start][:line]).to eq(1)
    expect(file_changes.first[:range][:end][:line]).to eq(1)
    expect(file_changes.first[:newText]).to eq("newvar = 'here'\n")

    expect(file_changes[1][:range]['start']['line']).to eq(1)
    expect(file_changes[1][:range]['start']['character']).to eq(10)
    expect(file_changes[1][:range]['end']['line']).to eq(1)
    expect(file_changes[1][:range]['end']['character']).to eq(15)
    expect(file_changes[1][:newText]).to eq("newvar")
  end
end
