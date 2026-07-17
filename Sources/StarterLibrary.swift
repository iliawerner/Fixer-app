import Foundation

/// A ready-made action the user can add from the library. Every `prompt` should
/// contain the `{text}` placeholder (substituted with the selection in
/// `ActionRunner`) and usually ends with "return only…" so nothing but the result
/// is pasted back.
struct StarterAction: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let prompt: String
    let mode: ActionOutputMode
}

enum StarterLibrary {
    static let all: [StarterAction] = [
        StarterAction(name: "Fix grammar", subtitle: "Clean up spelling & phrasing",
                      prompt: "Fix grammar and make it sound simple and natural: {text}. Return only the corrected text.", mode: .replace),
        StarterAction(name: "Translate → English", subtitle: "Any language → English",
                      prompt: "Translate this to English: {text}. Return only the translation.", mode: .replace),
        StarterAction(name: "Summarize", subtitle: "Three short bullet points",
                      prompt: "Summarize in three short bullet points: {text}", mode: .replace),
        StarterAction(name: "Professional tone", subtitle: "Clear and professional",
                      prompt: "Rewrite in a clear, professional tone: {text}. Return only the rewritten text.", mode: .replace),
        StarterAction(name: "Explain simply", subtitle: "Plain language",
                      prompt: "Explain this in plain language: {text}", mode: .replace),
        StarterAction(name: "Shorten", subtitle: "Make it more concise",
                      prompt: "Make this shorter and tighter without losing meaning: {text}. Return only the result.", mode: .replace),
        StarterAction(name: "Bullet points", subtitle: "Turn prose into a list",
                      prompt: "Turn this into clear, scannable bullet points: {text}", mode: .replace),
        StarterAction(name: "Reply draft", subtitle: "Draft a response",
                      prompt: "Write a concise, friendly reply to this message: {text}", mode: .append),
        StarterAction(name: "Make friendly", subtitle: "Warmer tone",
                      prompt: "Rewrite this in a warm, friendly tone: {text}. Return only the rewritten text.", mode: .replace),
        StarterAction(name: "Key takeaways", subtitle: "Extract the essentials",
                      prompt: "List the key takeaways from this: {text}", mode: .replace),
    ]
}
