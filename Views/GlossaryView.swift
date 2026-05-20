import SwiftUI

struct GlossaryEntry: Identifiable, Hashable {
    let term: String
    let shortDefinition: String
    let significance: String
    let contexts: [String]
    let relatedTerms: [String]

    var id: String { term }

    var searchableText: String {
        ([term, shortDefinition, significance] + contexts + relatedTerms).joined(separator: " ")
    }
}

enum RadixGlossary {
    static let entries: [GlossaryEntry] = [
        GlossaryEntry(
            term: "Character",
            shortDefinition: "One Chinese written unit, such as 中, 國, or 學.",
            significance: "Characters are the basic dictionary items in Radix. They can have stroke order, parts, definition, notes, favorites, and related phrases.",
            contexts: ["Browse Dictionary", "Character info card", "Study", "My Data > Memory"],
            relatedTerms: ["Phrase", "Parts", "Radical", "Stroke Order"]
        ),
        GlossaryEntry(
            term: "Phrase",
            shortDefinition: "Two or more characters that work together as a dictionary word or useful expression.",
            significance: "Phrases help you understand real text. A phrase can be added, favorited, hidden for review, or shown on saved pages.",
            contexts: ["Phrase button", "Phrase Library", "Browse Pages", "Study", "Import From AI", "Review Added Phrases"],
            relatedTerms: ["Added Phrase", "Hidden", "Rejected", "Favorite"]
        ),
        GlossaryEntry(
            term: "Parts",
            shortDefinition: "The smaller written pieces Radix shows inside a character.",
            significance: "Parts help you see how a character is built and let you jump to related characters that share the same piece.",
            contexts: ["Character info card", "Character Breakdown"],
            relatedTerms: ["Structure", "Radical", "Character Breakdown"]
        ),
        GlossaryEntry(
            term: "Structure",
            shortDefinition: "The layout pattern of a character, such as left-right, top-bottom, or enclosing.",
            significance: "Structure is useful for filtering and understanding why parts appear in a certain arrangement.",
            contexts: ["Browse Filters", "Character info card"],
            relatedTerms: ["Parts", "Radical", "Browse Filters"]
        ),
        GlossaryEntry(
            term: "Radical",
            shortDefinition: "A key component traditionally used to organize Chinese characters in dictionaries.",
            significance: "Radix highlights radicals where known because they often hint at meaning or dictionary grouping.",
            contexts: ["Browse Filters", "Character info card", "Character Breakdown"],
            relatedTerms: ["Parts", "Structure"]
        ),
        GlossaryEntry(
            term: "Simplified",
            shortDefinition: "The simplified Chinese writing form used mainly in mainland China and Singapore.",
            significance: "Switching to Simplified changes how characters and phrases are displayed where Radix supports both forms.",
            contexts: ["简 button", "Browse Pages", "Study", "Phrase info card", "Image script"],
            relatedTerms: ["Traditional", "Character Set"]
        ),
        GlossaryEntry(
            term: "Traditional",
            shortDefinition: "The traditional Chinese writing form used mainly in Taiwan, Hong Kong, and many classical sources.",
            significance: "Switching to Traditional changes display form without changing the underlying memory item.",
            contexts: ["繁 button", "Browse Pages", "Study", "Phrase info card", "Image script"],
            relatedTerms: ["Simplified", "Character Set"]
        ),
        GlossaryEntry(
            term: "Definition",
            shortDefinition: "The meaning Radix shows for a character or phrase.",
            significance: "Definitions help quick understanding. You can add notes when the built-in meaning is not enough for your use.",
            contexts: ["Character info card", "Phrase info card", "Search results"],
            relatedTerms: ["Meaning", "Notes"]
        ),
        GlossaryEntry(
            term: "Meaning",
            shortDefinition: "The English explanation shown for a phrase.",
            significance: "Meaning is the phrase equivalent of a character definition.",
            contexts: ["Phrase info card", "Phrase Library", "Review Added Phrases"],
            relatedTerms: ["Definition", "Notes"]
        ),
        GlossaryEntry(
            term: "Origin",
            shortDefinition: "A short note about where a character form or idea may come from.",
            significance: "Origin is there to aid memory. It is not required for using the character, and some characters may not have it.",
            contexts: ["Character info card"],
            relatedTerms: ["Parts", "Structure"]
        ),
        GlossaryEntry(
            term: "Notes",
            shortDefinition: "Your own comments, examples, sentences, or reminders.",
            significance: "Notes are part of Radix Memory and travel with your data. They let you adapt Radix to how you personally study.",
            contexts: ["Character info card", "Phrase info card", "My Data > Memory"],
            relatedTerms: ["Memory", "Character", "Phrase"]
        ),
        GlossaryEntry(
            term: "Tier",
            shortDefinition: "A rough level showing how common or useful a character is likely to be.",
            significance: "Tier helps prioritize study. Lower tiers are generally more central; higher tiers are more specialized or rare.",
            contexts: ["Character info card", "Browse Dictionary"],
            relatedTerms: ["Study", "Favorite"]
        ),
        GlossaryEntry(
            term: "Stroke Order",
            shortDefinition: "The order in which strokes are written for a character.",
            significance: "Stroke order helps handwriting, recognition, and memory. Radix shows stroke animation when data is available.",
            contexts: ["Character animation", "Character info card", "Apple stroke keyboard help"],
            relatedTerms: ["Character", "Parts"]
        ),
        GlossaryEntry(
            term: "Memory",
            shortDefinition: "Everything you have added, saved, favorited, changed, or set up in Radix.",
            significance: "Memory is what you protect with dated copies or move to another device. It includes your work, not just dictionary data.",
            contexts: ["My Data > Memory", "Save Memory", "Restore Memory", "Reset Radix Memory"],
            relatedTerms: ["Dated Copy", "Other Devices", "Added", "Favorite"]
        ),
        GlossaryEntry(
            term: "Added",
            shortDefinition: "A character or phrase you put into Radix yourself.",
            significance: "Added items belong to your Memory. They can be reviewed, edited, hidden, rejected, deleted, backed up, and restored.",
            contexts: ["Characters You Added", "Phrases You Added", "Import From AI", "Add Phrase", "Add Character"],
            relatedTerms: ["Memory", "Added Phrase", "Checked", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Added Phrase",
            shortDefinition: "A phrase you added yourself, often from AI extraction or manual entry.",
            significance: "Added phrases may need review because AI or OCR can produce weak groupings. Review lets you keep, hide, or reject them.",
            contexts: ["Phrases You Added", "Review Added Phrases", "Classify & Prune", "Make AI Text Page"],
            relatedTerms: ["Checked", "Hidden", "Rejected", "Make AI Text Page"]
        ),
        GlossaryEntry(
            term: "Favorite",
            shortDefinition: "A character, phrase, or page you marked with a star.",
            significance: "Favorites stay in Study even after you clear recent items, so they are the subset you want to keep reviewing.",
            contexts: ["Star button", "Study", "Favorites", "Saved Pages"],
            relatedTerms: ["Study", "Recent", "Saved Page"]
        ),
        GlossaryEntry(
            term: "Recent",
            shortDefinition: "Characters, phrases, or pages you have recently viewed or studied.",
            significance: "Recent items are temporary review material. Clear them after deciding what deserves a star.",
            contexts: ["Study", "Recent study strip", "Clear Recent", "Recent Saved Items"],
            relatedTerms: ["Favorite", "Study"]
        ),
        GlossaryEntry(
            term: "Study",
            shortDefinition: "The place to review recent items and favorites.",
            significance: "Study helps you decide what deserves more attention. Star useful items, then clear recent items after review.",
            contexts: ["Study tab"],
            relatedTerms: ["Favorite", "Recent", "Clear Recent"]
        ),
        GlossaryEntry(
            term: "Checked",
            shortDefinition: "An added phrase you reviewed and accept as a useful phrase.",
            significance: "Checked phrases stay visible in normal phrase lists and can continue to help Browse and Study.",
            contexts: ["Review Added Phrases", "Phrases You Added"],
            relatedTerms: ["Added Phrase", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Hidden",
            shortDefinition: "An added phrase you do not want in normal phrase lists, but may still want for page understanding.",
            significance: "Hidden phrases can still help page review and highlighting, but they stay out of the regular Phrase button/list.",
            contexts: ["Review Added Phrases", "Page Phrases", "Browse Pages"],
            relatedTerms: ["Added Phrase", "Checked", "Rejected"]
        ),
        GlossaryEntry(
            term: "Rejected",
            shortDefinition: "A character grouping you decided is not a real phrase for Radix.",
            significance: "Rejected is remembered so the same grouping does not quietly return as an added phrase. You can restore it to New if needed.",
            contexts: ["Review Added Phrases", "Classify & Prune"],
            relatedTerms: ["Added Phrase", "New", "Hidden"]
        ),
        GlossaryEntry(
            term: "New",
            shortDefinition: "An added phrase that has not yet been checked, hidden, or rejected.",
            significance: "New phrases are waiting for review. They are not necessarily good or bad yet.",
            contexts: ["Review Added Phrases"],
            relatedTerms: ["Checked", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Saved Page",
            shortDefinition: "A scanned or pasted page kept in Radix for browsing later.",
            significance: "Saved pages preserve page text, phrase choices, translation, and context so you can revisit real reading material.",
            contexts: ["Browse > Saved Pages", "Capture", "Study Pages", "My Data > Memory"],
            relatedTerms: ["Page Phrases", "Translation", "AI Link"]
        ),
        GlossaryEntry(
            term: "Page Phrases",
            shortDefinition: "Phrases Radix found on a saved page.",
            significance: "You can show or hide page phrases depending on whether they fit the page context. This does not necessarily delete the phrase from Memory.",
            contexts: ["Browse Pages", "Page Phrases sheet"],
            relatedTerms: ["Saved Page", "Hidden", "Phrase"]
        ),
        GlossaryEntry(
            term: "Dated Copy",
            shortDefinition: "A time-stamped copy of your Radix Memory kept on this device.",
            significance: "Dated copies let you restore your work on the same device. They are not files for moving to another device.",
            contexts: ["My Data > This Device", "Save Dated Copy", "Restore Memory"],
            relatedTerms: ["Memory", "This Device", "Other Devices"]
        ),
        GlossaryEntry(
            term: "This Device",
            shortDefinition: "Backups kept on the current iPhone, iPad, or Mac.",
            significance: "Use This Device when you want a dated copy you can restore here later.",
            contexts: ["My Data > This Device"],
            relatedTerms: ["Dated Copy", "Other Devices", "Memory"]
        ),
        GlossaryEntry(
            term: "Other Devices",
            shortDefinition: "Files meant to move your Radix Memory to another iPhone, iPad, or Mac.",
            significance: "Other Devices is for data portability across devices. It is separate from dated copies kept on this device.",
            contexts: ["My Data > Other Devices", "Save Memory", "Restore Memory"],
            relatedTerms: ["Memory", "This Device", "Data Portability"]
        ),
        GlossaryEntry(
            term: "Data Portability",
            shortDefinition: "The ability to carry your Radix work between iPhone, iPad, and Mac.",
            significance: "This is why Radix separates Memory from the app itself: your work can move with you.",
            contexts: ["My Data", "Other Devices", "Upgrade"],
            relatedTerms: ["Memory", "Other Devices"]
        ),
        GlossaryEntry(
            term: "AI Link",
            shortDefinition: "Repeatable AI actions that help Radix do work it cannot do alone.",
            significance: "AI Link can create instructions for AI, extract phrases, translate pages, or save translation results when an API key is available.",
            contexts: ["AI Link tab", "Browse page actions", "Settings"],
            relatedTerms: ["Instruction", "API Key", "Extract Phrases", "Translation"]
        ),
        GlossaryEntry(
            term: "Instruction",
            shortDefinition: "Text Radix prepares for an AI service to follow.",
            significance: "Good instructions help AI return cleaner phrases, translations, or explanations in the format Radix expects.",
            contexts: ["AI Link", "Instruction output"],
            relatedTerms: ["AI Link", "Extract Phrases", "Translation"]
        ),
        GlossaryEntry(
            term: "API Key",
            shortDefinition: "A private key that lets Radix call an AI service directly.",
            significance: "Without an API key, you can still copy instructions and paste results manually. With a key, Radix can combine steps automatically.",
            contexts: ["Settings > Private API Keys", "Extract Phrases Automatically", "Translate and Save"],
            relatedTerms: ["AI Link", "Gemini API Key"]
        ),
        GlossaryEntry(
            term: "Extract Phrases",
            shortDefinition: "Ask AI or Radix to find useful dictionary phrases from page text or characters.",
            significance: "Extraction can add many candidate phrases quickly, but they may need review before they become trusted Memory.",
            contexts: ["AI Link menu", "Import From AI", "Review Added Phrases"],
            relatedTerms: ["Added Phrase", "Classify & Prune", "Make AI Text Page"]
        ),
        GlossaryEntry(
            term: "Translation",
            shortDefinition: "An AI-generated translation or explanation of a saved page.",
            significance: "Translations can be saved with the page so you can read the original and the explanation together later.",
            contexts: ["Browse page actions", "View Translation", "Save Translation", "Translate and Save"],
            relatedTerms: ["Saved Page", "AI Link"]
        ),
        GlossaryEntry(
            term: "Classify & Prune",
            shortDefinition: "Review added phrases and mark them as New, Checked, Hidden, or Rejected.",
            significance: "This keeps your phrase memory useful instead of becoming a long list of weak AI/OCR groupings.",
            contexts: ["My Data > Memory > Phrases You Added"],
            relatedTerms: ["Added Phrase", "Checked", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Make AI Text Page",
            shortDefinition: "Create a text page from added phrases so AI can inspect them again.",
            significance: "This helps you ask AI to sieve or clean a large phrase list using the exact characters in your added phrases.",
            contexts: ["My Data > Memory > Phrases You Added"],
            relatedTerms: ["Added Phrase", "Extract Phrases", "AI Link"]
        )
    ].sorted { $0.term.localizedStandardCompare($1.term) == .orderedAscending }

    static func entry(for term: String) -> GlossaryEntry? {
        entries.first { $0.term.localizedCaseInsensitiveCompare(term) == .orderedSame }
    }
}

struct GlossaryView: View {
    @State private var searchText = ""

    private var filteredEntries: [GlossaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return RadixGlossary.entries }
        return RadixGlossary.entries.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                Text("A plain-language reference for Radix terms, where they appear, and what changing them affects.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(filteredEntries) { entry in
                NavigationLink {
                    GlossaryDetailView(entry: entry)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.term)
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Text(entry.shortDefinition)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Glossary")
        .searchable(text: $searchText, prompt: "Search Radix terms")
    }
}

struct GlossaryDetailView: View {
    let entry: GlossaryEntry

    var body: some View {
        List {
            Section("Meaning") {
                Text(entry.shortDefinition)
            }

            Section("Why It Matters") {
                Text(entry.significance)
            }

            Section("Used In") {
                ForEach(entry.contexts, id: \.self) { context in
                    Label(context, systemImage: "location")
                }
            }

            if !entry.relatedTerms.isEmpty {
                Section("Related Terms") {
                    ForEach(entry.relatedTerms, id: \.self) { term in
                        if let relatedEntry = RadixGlossary.entry(for: term) {
                            NavigationLink(term) {
                                GlossaryDetailView(entry: relatedEntry)
                            }
                        } else {
                            Text(term)
                        }
                    }
                }
            }
        }
        .navigationTitle(entry.term)
    }
}

struct GlossaryTermButton: View {
    let term: String
    var compact: Bool = true
    @State private var isPresented = false

    private var entry: GlossaryEntry? {
        RadixGlossary.entry(for: term)
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            if compact {
                Image(systemName: "info.circle")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(term, systemImage: "info.circle")
            }
        }
        .buttonStyle(.plain)
        .disabled(entry == nil)
        .accessibilityLabel("Explain \(term)")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            if let entry {
                GlossaryInlineCard(entry: entry)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

struct GlossaryInlineCard: View {
    let entry: GlossaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.term)
                .font(ResponsiveFont.headline)

            Text(entry.shortDefinition)
                .font(ResponsiveFont.caption)

            Text(entry.significance)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if !entry.contexts.isEmpty {
                Text("Used in: \(entry.contexts.prefix(3).joined(separator: ", "))")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
    }
}
