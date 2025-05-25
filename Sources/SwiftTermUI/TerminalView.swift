import SwiftUI

public struct TerminalView: View {
    @State private var model = HeadlessTerminalModel()
    @State private var inputText = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(model.terminalOutput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(UIColor.systemBackground))
            
            HStack {
                TextField("Enter command", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !inputText.isEmpty {
                            model.executeCommand(inputText)
                            inputText = ""
                        }
                    }
                
                Button("Send") {
                    if !inputText.isEmpty {
                        model.executeCommand(inputText)
                        inputText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}