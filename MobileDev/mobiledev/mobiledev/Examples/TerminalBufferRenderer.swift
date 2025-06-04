//
//  TerminalBufferRenderer.swift
//  mobiledev
//
//  Advanced example showing how to extract styled content from terminal buffers
//

import SwiftUI
import SwiftTerm

/// A struct representing a styled character from the terminal
struct StyledCharacter {
    let character: String
    let foregroundColor: Color?
    let backgroundColor: Color?
    let isBold: Bool
    let isUnderlined: Bool
    let isItalic: Bool
    let isDim: Bool
}

/// A struct representing a styled line from the terminal
struct StyledLine {
    let characters: [StyledCharacter]
    let isWrapped: Bool
}

/// Advanced terminal buffer renderer that extracts styled content
class TerminalBufferRenderer: ObservableObject {
    private let terminal: Terminal
    private let delegate: DisplayOnlyTerminalDelegate
    
    @Published var styledLines: [StyledLine] = []
    
    init(cols: Int = 80, rows: Int = 24) {
        self.delegate = DisplayOnlyTerminalDelegate()
        self.terminal = Terminal(
            delegate: delegate,
            options: TerminalOptions(cols: cols, rows: rows)
        )
    }
    
    /// Feed data and extract styled content
    func feedAndExtractStyles(_ text: String) {
        terminal.feed(text: text)
        extractStyledContent()
    }
    
    /// Extract styled content from the terminal buffer
    private func extractStyledContent() {
        var lines: [StyledLine] = []
        
        let buffer = terminal.buffer
        let yDisp = buffer.yDisp
        let yBase = buffer.yBase
        
        // Iterate through visible lines
        for row in 0..<terminal.rows {
            let bufferRow = yBase + yDisp + row
            
            guard bufferRow >= 0 && bufferRow < buffer.lines.count else {
                continue
            }
            
            let line = buffer.lines[bufferRow]
            var characters: [StyledCharacter] = []
            
            // Extract each character with its attributes
            for col in 0..<terminal.cols {
                let charData = line[col]
                let attr = charData.attribute
                
                // Convert character code to string
                let char = charData.code == 0 ? " " : charData.getCharacter()
                
                // Extract colors
                let fgColor = convertColor(attr.fg, isForeground: true)
                let bgColor = convertColor(attr.bg, isForeground: false)
                
                // Create styled character
                let styledChar = StyledCharacter(
                    character: char,
                    foregroundColor: fgColor,
                    backgroundColor: bgColor,
                    isBold: attr.isBold,
                    isUnderlined: attr.isUnderline,
                    isItalic: attr.isItalic,
                    isDim: attr.isDim
                )
                
                characters.append(styledChar)
            }
            
            lines.append(StyledLine(
                characters: characters,
                isWrapped: line.isWrapped
            ))
        }
        
        self.styledLines = lines
    }
    
    /// Convert terminal color to SwiftUI Color
    private func convertColor(_ color: Attribute.Color, isForeground: Bool) -> Color? {
        switch color {
        case .defaultColor:
            return isForeground ? .primary : .clear
        case .defaultInvertedColor:
            return isForeground ? .black : .white
        case .ansi256(let index):
            return ansiToColor(Int(index))
        case .trueColor(let r, let g, let b):
            return Color(red: Double(r) / 255.0,
                        green: Double(g) / 255.0,
                        blue: Double(b) / 255.0)
        }
    }
    
    /// Convert ANSI color index to SwiftUI Color
    private func ansiToColor(_ index: Int) -> Color {
        // Basic 16 colors
        switch index {
        case 0: return .black
        case 1: return .red
        case 2: return .green
        case 3: return .yellow
        case 4: return .blue
        case 5: return Color(red: 0.5, green: 0, blue: 0.5) // magenta
        case 6: return .cyan
        case 7: return .gray
        case 8: return Color(white: 0.3) // bright black
        case 9: return Color(red: 1, green: 0.5, blue: 0.5) // bright red
        case 10: return Color(red: 0.5, green: 1, blue: 0.5) // bright green
        case 11: return Color(red: 1, green: 1, blue: 0.5) // bright yellow
        case 12: return Color(red: 0.5, green: 0.5, blue: 1) // bright blue
        case 13: return Color(red: 1, green: 0.5, blue: 1) // bright magenta
        case 14: return Color(red: 0.5, green: 1, blue: 1) // bright cyan
        case 15: return .white
        default:
            // For 256 color mode, approximate
            if index < 232 {
                // Color cube
                let idx = index - 16
                let r = (idx / 36) % 6
                let g = (idx / 6) % 6
                let b = idx % 6
                return Color(
                    red: Double(r) / 5.0,
                    green: Double(g) / 5.0,
                    blue: Double(b) / 5.0
                )
            } else {
                // Grayscale
                let gray = Double(index - 232) / 23.0
                return Color(white: gray)
            }
        }
    }
}

// MARK: - SwiftUI Views

/// A view that renders a styled line from the terminal
struct StyledLineView: View {
    let line: StyledLine
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(line.characters.enumerated()), id: \.offset) { _, char in
                StyledCharacterView(character: char)
            }
            Spacer()
        }
    }
}

/// A view that renders a single styled character
struct StyledCharacterView: View {
    let character: StyledCharacter
    
    var body: some View {
        Text(character.character)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(character.foregroundColor ?? .primary)
            .background(character.backgroundColor ?? .clear)
            .bold(character.isBold)
            .italic(character.isItalic)
            .underline(character.isUnderlined)
            .opacity(character.isDim ? 0.5 : 1.0)
    }
}

/// Example view showing styled terminal rendering
struct TerminalBufferRendererView: View {
    @StateObject private var renderer = TerminalBufferRenderer()
    @State private var showStyled = true
    
    let sampleOutputs = [
        "Simple": "Hello, World!",
        "Colors": "\u{1b}[31mRed\u{1b}[0m \u{1b}[32mGreen\u{1b}[0m \u{1b}[34mBlue\u{1b}[0m",
        "Styles": "\u{1b}[1mBold\u{1b}[0m \u{1b}[3mItalic\u{1b}[0m \u{1b}[4mUnderline\u{1b}[0m",
        "Progress": "[\u{1b}[42m    \u{1b}[0m      ] 40%",
        "Complex": "\u{1b}[1;32m✓\u{1b}[0m Success\n\u{1b}[1;31m✗\u{1b}[0m Failed\n\u{1b}[1;33m!\u{1b}[0m Warning"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Terminal Buffer Renderer")
                .font(.title)
            
            HStack {
                ForEach(Array(sampleOutputs.keys.sorted()), id: \.self) { key in
                    Button(key) {
                        if let output = sampleOutputs[key] {
                            renderer.feedAndExtractStyles(output)
                        }
                    }
                }
                
                Spacer()
                
                Toggle("Show Styled", isOn: $showStyled)
            }
            
            GroupBox("Rendered Output") {
                ScrollView {
                    if showStyled {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(renderer.styledLines.enumerated()), id: \.offset) { _, line in
                                StyledLineView(line: line)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(renderer.terminal.getBufferAsData()
                            .map { String(data: $0, encoding: .utf8) ?? "" } ?? "")
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .background(Color.black)
                .foregroundColor(.white)
            }
            
            // Debug info
            GroupBox("Buffer Info") {
                VStack(alignment: .leading) {
                    Text("Lines: \(renderer.styledLines.count)")
                    Text("Terminal: \(renderer.terminal.cols)×\(renderer.terminal.rows)")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .onAppear {
            // Load initial sample
            renderer.feedAndExtractStyles(sampleOutputs["Complex"] ?? "")
        }
    }
}

// MARK: - Preview

struct TerminalBufferRendererView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalBufferRendererView()
    }
}