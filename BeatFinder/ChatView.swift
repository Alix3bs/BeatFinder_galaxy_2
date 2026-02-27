import SwiftUI

struct Conversation: Identifiable {
    let id: UUID = UUID()
    let name: String
}

struct ChatView: View {

    let message: Conversation
    @Environment(\.selectedTheme) var selectedTheme
    @State private var inputText: String = ""

    @State private var chat: [String] = [

        "Yo, that beat was insane!",

        "Appreciate it 🙏 I’m working on a remix pack now."

    ]

    

    var body: some View {

        ZStack {
            ThemeManager.backgroundGradient(for: selectedTheme)
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 45, height: 45)
                        .overlay(Text(String(message.name.prefix(1))).foregroundColor(.white))
                    Text(message.name)
                        .font(.headline)
                        .foregroundColor(Color.primary)
                    Spacer()
                }
                .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(chat, id: \.self) { msg in
                            HStack {
                                Text(msg)
                                    .padding()
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(Color.primary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    TextField("Message...", text: $inputText)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(Color.primary)
                    
                    Button(action: {
                        if !inputText.isEmpty {
                            chat.append(inputText)
                            inputText = ""
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(ThemeManager.accentColor(for: selectedTheme))
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 15)
            }
        }

    }

}


