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

    var systemImage: String {
        RadixGlossaryIcon.systemImage(for: term)
    }
}

enum RadixGlossary {
    static let entries: [GlossaryEntry] = [
        GlossaryEntry(
            term: "Character",
            shortDefinition: "One Chinese written unit, such as 中, 國, or 學.",
            significance: "Characters are the basic dictionary items in Radix. They can have stroke order, components, definition, notes, favorites, and related phrases.",
            contexts: ["Browse Dictionary", "Character info card", "Study", "Backup Contents"],
            relatedTerms: ["Phrase", "Components", "Radical", "Stroke Order"]
        ),
        GlossaryEntry(
            term: "Phrase",
            shortDefinition: "Two or more characters that work together as a dictionary word or useful expression.",
            significance: "Phrases help you understand real text. A phrase can be added, favorited, hidden for review, or shown on saved pages.",
            contexts: ["Phrase button", "Phrase Library", "Browse Pages", "Study", "Import From AI", "Review Added Phrases", "Sentence Phrases"],
            relatedTerms: ["Added Phrase", "Hidden", "Rejected", "Favorite", "Sentence"]
        ),
        GlossaryEntry(
            term: "Components",
            shortDefinition: "The smaller written pieces Radix shows inside a character.",
            significance: "Components help you see how a character is built and let you jump to related characters that share the same piece.",
            contexts: ["Character info card", "Character Breakdown"],
            relatedTerms: ["Structure", "Radical", "Character Breakdown"]
        ),
        GlossaryEntry(
            term: "Structure",
            shortDefinition: "The layout pattern of a character, such as left-right, top-bottom, or enclosing.",
            significance: "Structure is useful for filtering and understanding why parts appear in a certain arrangement.",
            contexts: ["Browse Filters", "Character info card"],
            relatedTerms: ["Components", "Radical", "Browse Filters"]
        ),
        GlossaryEntry(
            term: "Radical",
            shortDefinition: "A key component traditionally used to organize Chinese characters in dictionaries.",
            significance: "Radix highlights radicals where known because they often hint at meaning or dictionary grouping.",
            contexts: ["Browse Filters", "Character info card", "Character Breakdown"],
            relatedTerms: ["Components", "Structure"]
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
            relatedTerms: ["Components", "Structure"]
        ),
        GlossaryEntry(
            term: "Notes",
            shortDefinition: "Your own comments, examples, sentences, or reminders.",
            significance: "Notes are part of Radix Memory and travel with your data. They let you adapt Radix to how you personally study.",
            contexts: ["Character info card", "Phrase info card", "Backup Contents"],
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
            relatedTerms: ["Character", "Components"]
        ),
        GlossaryEntry(
            term: "Memory",
            shortDefinition: "Everything you have added, saved, favorited, changed, or set up in Radix.",
            significance: "Memory is what you preserve with local snapshots and protect with iCloud backups. It includes your work, not just dictionary data.",
            contexts: ["Backup Contents", "Create Checkpoint", "Return to Checkpoint", "Erase My Data", "My Data > Backup File"],
            relatedTerms: ["Checkpoint", "Radix Plus", "Backup", "Added", "Favorite", "Favorite Sentence"]
        ),
        GlossaryEntry(
            term: "History",
            shortDefinition: "The short-term exploration trail for characters and phrases you recently touched.",
            significance: "History is working memory for exploration, not global navigation. Its role is to help you quickly recall the characters and phrases you have been inspecting, especially while searching, browsing saved pages, and following character or phrase details. On larger screens, it can stay visible beside info cards because there is room to explore and compare. On iPhone, it should be more selective because space is precious: Search and Browse are its natural homes, while Study already has Recent for deliberate review, My Data is stored memory, and AI Link or Settings should stay focused on their own workflows.",
            contexts: ["Search", "Browse", "Saved Pages", "Character info card", "Phrase info card"],
            relatedTerms: ["Memory", "Recent", "Study", "Saved Page", "Character", "Phrase"]
        ),
        GlossaryEntry(
            term: "Added",
            shortDefinition: "A character or phrase you put into Radix yourself.",
            significance: "Added items belong to your Memory. They can be reviewed, edited, hidden, rejected, deleted, backed up, and restored.",
            contexts: ["Characters You Added", "Phrases You Added", "Import From AI", "Add Phrase", "Add Character"],
            relatedTerms: ["Memory", "Added Phrase", "Accepted", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Added Phrase",
            shortDefinition: "A phrase you added yourself, often from AI extraction or manual entry.",
            significance: "Added phrases may need review because AI or OCR can produce weak groupings. Review lets you keep, hide, or reject them.",
            contexts: ["Phrases You Added", "Review Added Phrases", "Classify & Prune", "Make AI Text Page"],
            relatedTerms: ["Accepted", "Hidden", "Rejected", "Make AI Text Page"]
        ),
        GlossaryEntry(
            term: "Favorite",
            shortDefinition: "A character, phrase, or page you marked with a star.",
            significance: "Favorites stay in Study even after you clear recent items, so they are the subset you want to keep reviewing.",
            contexts: ["Star button", "Study", "Favorites", "Saved Pages"],
            relatedTerms: ["Study", "Recent", "Saved Page", "Favorite Sentence"]
        ),
        GlossaryEntry(
            term: "Sentence",
            shortDefinition: "A complete Chinese line used for reading, listening, translation, or conversation practice.",
            significance: "Sentences give characters and phrases real context. In Radix, a sentence can be read aloud, inspected for useful phrases, favorited into Study, translated, edited, and practiced again. Sentence favorites are kept separate from phrase favorites so the star does not confuse a complete sentence with one dictionary phrase inside it.",
            contexts: ["Conversation Practice", "Sentence Card", "Favorite Sentences", "Extract Sentences", "Sentence Practice", "Create Conversation", "Sentences in Study"],
            relatedTerms: ["Phrase", "Sentence Phrases", "Favorite Sentence", "Saved Sentences", "Conversation Practice", "Practice Pack"]
        ),
        GlossaryEntry(
            term: "Saved Sentences",
            shortDefinition: "The shared place where Radix keeps sentences you can study.",
            significance: "Radix keeps favorite, page-derived, OCR-derived, and practice sentences together so the same sentence can appear in Study, Conversation Practice, and page work without becoming several unrelated copies. Because this library can grow large, it moves through Study > Sentences > Transfer instead of normal backup files.",
            contexts: ["Study > Sentences", "Favorite Sentences", "Extract Sentences", "Sentence Practice", "Conversation Practice", "Sentence Library"],
            relatedTerms: ["Sentence", "Sentence Example", "Favorite Sentence", "Conversation Practice", "Practice Pack", "Optimize Study Data", "Sentence Library"]
        ),
        GlossaryEntry(
            term: "Sentence Example",
            shortDefinition: "One saved sentence that Radix can show, search, or practice.",
            significance: "A sentence example can remember Chinese text, pinyin, English, useful phrases, notes, and where it came from. Editing it updates the shared sentence instead of creating another copy.",
            contexts: ["Study > Sentences", "Sentence actions", "Sentence Card", "Sentence Library"],
            relatedTerms: ["Saved Sentences", "Sentence", "Favorite Sentence", "Practice Pack"]
        ),
        GlossaryEntry(
            term: "Sentence Phrases",
            shortDefinition: "Useful phrases Radix shows inside a selected practice sentence.",
            significance: "Sentence Phrases let you inspect the parts of a complete sentence without losing the sentence context. They are different from the full Phrase Library because they are scoped to the sentence you are studying.",
            contexts: ["Sentence Card", "Phrase Library", "Conversation Practice"],
            relatedTerms: ["Sentence", "Phrase", "Conversation Practice"]
        ),
        GlossaryEntry(
            term: "Favorite Sentence",
            shortDefinition: "A complete practice sentence you saved with the star.",
            significance: "Favorite sentences become their own generated Conversation Practice set inside Study. They are part of the Sentence Library, while favorite characters, phrases, and pages remain part of normal Radix data.",
            contexts: ["Sentence Card", "Study", "Favorite Sentences", "Sentence Library"],
            relatedTerms: ["Sentence", "Favorite", "Conversation Practice", "Practice Pack", "Sentence Library"]
        ),
        GlossaryEntry(
            term: "Sentence Library",
            shortDefinition: "The separate sentence collection that can be transferred outside normal backup.",
            significance: "Sentence Library keeps large sentence data out of normal backup and restore, so backup and restore stay fast. Use Study > Sentences > Transfer for fast moves between Radix devices, or Advanced Exports when you need a portable file for inspection.",
            contexts: ["Study > Sentences", "Advanced Exports", "Extract Sentences"],
            relatedTerms: ["Saved Sentences", "Sentence Example", "Favorite Sentence", "Backup"]
        ),
        GlossaryEntry(
            term: "Conversation Practice",
            shortDefinition: "A Study mode for practicing complete Chinese sentences by theme or saved source.",
            significance: "Conversation Practice turns sentences into review material with reading, speech, translation, flashcards, quizzes, and phrase inspection. It is where AI-generated or page-extracted practice packs become usable study material inside Radix.",
            contexts: ["Study", "Generate Practice Pack", "Sentence Practice", "Create Conversation", "Favorite Sentences"],
            relatedTerms: ["Sentence", "Saved Sentences", "Practice Pack", "Favorite Sentence", "Sentence Practice", "Create Conversation"]
        ),
        GlossaryEntry(
            term: "Practice Pack",
            shortDefinition: "A structured set of conversation-practice sentences that Radix can import.",
            significance: "Practice packs let AI or saved pages produce sentences that return to Radix as real Study material. Radix links imported practice entries back to saved sentences when possible, so the pack acts as grouping and sequence rather than another copy of the same sentences.",
            contexts: ["AI Link", "Import Practice", "Conversation Practice", "Generate Practice Pack"],
            relatedTerms: ["Conversation Practice", "Sentence", "Saved Sentences", "Sentence Practice", "Create Conversation"]
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
            shortDefinition: "The page-first place to review what you decided to keep.",
            significance: "Study follows the model Pages -> Artifacts -> Practice -> Memory -> Checkpoints. Saved pages gather their translations, page phrases, quizzes, Sentences, Conversation practice, corrected text, learning memory, and recovery checkpoints in one review area.",
            contexts: ["Study tab", "Saved Pages", "Sentences", "Conversation Practices", "Checkpoints"],
            relatedTerms: ["Saved Page", "Page Artifact", "Practice Pack", "Saved Sentences", "Memory", "Checkpoint"]
        ),
        GlossaryEntry(
            term: "Accepted",
            shortDefinition: "An added phrase you reviewed and accept as a useful phrase.",
            significance: "Accepted phrases stay in the review cycle as useful phrases. You can still hide, reject, or mark them Unreviewed if your judgment changes.",
            contexts: ["Review Added Phrases", "Phrases You Added"],
            relatedTerms: ["Added Phrase", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Hidden",
            shortDefinition: "An added phrase you do not want in normal phrase lists, but may still want for page understanding.",
            significance: "Hidden phrases can still help page review and highlighting, but they stay out of the regular Phrase button/list.",
            contexts: ["Review Added Phrases", "Page Phrases", "Browse Pages"],
            relatedTerms: ["Added Phrase", "Accepted", "Rejected"]
        ),
        GlossaryEntry(
            term: "Rejected",
            shortDefinition: "A character grouping you decided is not a real phrase for Radix.",
            significance: "Rejected is remembered so the same grouping does not quietly return as an added phrase. You can mark it Unreviewed if needed.",
            contexts: ["Review Added Phrases", "Classify & Prune"],
            relatedTerms: ["Added Phrase", "Unreviewed", "Hidden"]
        ),
        GlossaryEntry(
            term: "Unreviewed",
            shortDefinition: "An added phrase that has not yet been accepted, hidden, or rejected.",
            significance: "Unreviewed phrases are waiting for a decision. They are not necessarily good or bad yet.",
            contexts: ["Review Added Phrases"],
            relatedTerms: ["Accepted", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Saved Page",
            shortDefinition: "A scanned or pasted page kept in Radix for browsing later.",
            significance: "Saved pages are the center of the Radix learning loop. They preserve the original Chinese and keep page-owned artifacts such as translation, corrected text, page phrases, quiz prompts, extracted Sentences, and page Conversation practice tied to the source.",
            contexts: ["Browse > Saved Pages", "Capture", "Study > Saved Pages", "Backup Contents"],
            relatedTerms: ["Page Artifact", "Page Phrases", "Translation", "AI Link", "Saved Sentences"]
        ),
        GlossaryEntry(
            term: "Page Artifact",
            shortDefinition: "Work created from a saved page and attached back to that page.",
            significance: "Page artifacts keep Radix organized around the original source. Translation, corrected text, page phrases, Sentences, Conversation practice, and quiz entry points belong with the saved page that produced them; reusable memory such as added phrases, favorites, and progress can outlive the page.",
            contexts: ["Study > Saved Pages", "Saved page actions", "Delete Saved Page", "Backup Contents"],
            relatedTerms: ["Saved Page", "Page Phrases", "Translation", "Extract Sentences", "Sentence Practice", "Create Conversation", "Memory"]
        ),
        GlossaryEntry(
            term: "Radix Plus",
            shortDefinition: "The annual Radix tier for unlimited page creation, import tools, local snapshots, and iCloud backup.",
            significance: "Radix Plus keeps the first 100 Camera or Text pages free, then unlocks unlimited pages, page creation from Album or Files, same-device checkpoints, and portable backup.",
            contexts: ["Upgrade", "Camera", "Text from Clipboard", "Image from Album", "Image from Files", "Create Checkpoint", "Return to Checkpoint", "Backup"],
            relatedTerms: ["Saved Page", "Checkpoint", "Backup"]
        ),
        GlossaryEntry(
            term: "Checkpoint",
            shortDefinition: "A time-stamped recovery point kept inside Radix on this device.",
            significance: "Device snapshots provide quick same-device recovery. They do not create a file for moving data to another device.",
            contexts: ["Create Checkpoint", "Return to Checkpoint", "My Data > Backup File", "Upgrade"],
            relatedTerms: ["Radix Plus", "Memory", "Backup"]
        ),
        GlossaryEntry(
            term: "Page Phrases",
            shortDefinition: "Phrases Radix found on a saved page.",
            significance: "You can show or hide page phrases depending on whether they fit the page context. This does not necessarily delete the phrase from Memory.",
            contexts: ["Browse Pages", "Page Phrases sheet"],
            relatedTerms: ["Saved Page", "Hidden", "Phrase"]
        ),
        GlossaryEntry(
            term: "Backup",
            shortDefinition: "A portable file that can move your Radix data between devices.",
            significance: "Backups are portable files for cross-device transfer and recovery. They are separate from checkpoints kept inside Radix on one device.",
            contexts: ["My Data > Backup File", "Create Backup", "Merge Backup", "Replace from Backup"],
            relatedTerms: ["Memory", "Checkpoint", "Radix Plus", "Data Portability"]
        ),
        GlossaryEntry(
            term: "Recovery Copies",
            shortDefinition: "Local safety copies Radix keeps before major data changes.",
            significance: "Recovery Copies help you undo a problem after import, restore, cleanup, or optimization on this device. They are not the same as a portable backup file for moving Radix to another device.",
            contexts: ["Settings > Storage", "Create Safety Copy Now", "Restore"],
            relatedTerms: ["Safety Copy", "Backup", "Optimize Study Data", "Memory"]
        ),
        GlossaryEntry(
            term: "Safety Copy",
            shortDefinition: "A local recovery copy made before or during maintenance.",
            significance: "Safety Copies are a safety net for data-changing actions. Radix can create them quietly before important maintenance, and you can also create one manually from Settings.",
            contexts: ["Settings > Storage", "Create Safety Copy Now", "Recovery Copies"],
            relatedTerms: ["Recovery Copies", "Backup", "Memory"]
        ),
        GlossaryEntry(
            term: "Storage",
            shortDefinition: "A quick check of how large your Radix study data has become.",
            significance: "Storage shows counts and file sizes without loading your whole library. It helps you see when backups or optimization may take longer, while keeping normal Study and Browse use fast.",
            contexts: ["Settings > Storage"],
            relatedTerms: ["Optimize Study Data", "Recovery Copies", "Saved Sentences", "Added Phrase"]
        ),
        GlossaryEntry(
            term: "Optimize Study Data",
            shortDefinition: "A background cleanup that keeps Radix fast and consistent.",
            significance: "Optimize Study Data prepares study data after large imports or cleanup. It keeps sentence search, phrase highlights, and saved-page sentence results working smoothly without asking you to manage technical storage details.",
            contexts: ["Settings > Storage", "After Restore", "After Import"],
            relatedTerms: ["Storage", "Recovery Copies", "Saved Sentences", "Phrase"]
        ),
        GlossaryEntry(
            term: "Data Portability",
            shortDefinition: "The ability to carry your Radix work between devices.",
            significance: "Radix keeps your work separate from the app itself so a compatible backup can move safely between supported devices and future platforms.",
            contexts: ["My Data > Backup", "Backup", "Upgrade"],
            relatedTerms: ["Memory", "Backup", "Radix Plus"]
        ),
        GlossaryEntry(
            term: "AI Link",
            shortDefinition: "A bridge from Radix to AI for understanding Chinese beyond fixed dictionary definitions.",
            significance: "Use AI Link to investigate nuance and current usage, understand language in context, translate complete pages naturally, and explore phrases or concepts that traditional dictionaries may not yet cover.",
            contexts: ["AI Link tab", "Browse page actions", "Study page actions", "Settings"],
            relatedTerms: ["AI Prompt", "Copy to AI Chat", "Run Automatically with Gemini", "API Key", "Extract Phrases", "Translation"]
        ),
        GlossaryEntry(
            term: "AI Prompt",
            shortDefinition: "Text Radix prepares for an AI service to follow.",
            significance: "Good AI prompts help AI return cleaner phrases, translations, or explanations in the format Radix expects.",
            contexts: ["AI Link", "AI Prompt output"],
            relatedTerms: ["AI Link", "Extract Phrases", "Translation"]
        ),
        GlossaryEntry(
            term: "API Key",
            shortDefinition: "A private key that lets Radix call an AI service directly.",
            significance: "Without an API key, you can still copy AI prompts and paste results manually. With a key, Radix can combine steps automatically.",
            contexts: ["Settings > Automatic AI", "Settings > Manual AI Keys", "Extract Phrases Automatically"],
            relatedTerms: ["AI Link", "Gemini API Key", "Run Automatically with Gemini", "Copy to AI Chat"]
        ),
        GlossaryEntry(
            term: "Copy to AI Chat",
            shortDefinition: "The copy-and-paste AI workflow where Radix prepares the prompt and you use your chosen AI chat.",
            significance: "Copy to AI Chat is the durable fallback for ChatGPT, Gemini, Claude, or another AI app. It keeps the user in control and works even when direct automation is unavailable.",
            contexts: ["AI Link", "Study page actions", "Browse page actions", "Paste AI Answer"],
            relatedTerms: ["AI Link", "AI Prompt", "Run Automatically with Gemini", "Page AI Task"]
        ),
        GlossaryEntry(
            term: "Run Automatically with Gemini",
            shortDefinition: "The direct in-app AI method Radix can run with a saved Gemini key.",
            significance: "Run Automatically with Gemini can run supported page AI tasks inside Radix, while Copy to AI Chat remains available for copy-and-paste workflows and for other AI chats.",
            contexts: ["Study page actions", "Browse page actions", "Settings > Automatic AI"],
            relatedTerms: ["Gemini API Key", "Copy to AI Chat", "API Key", "Page AI Task"]
        ),
        GlossaryEntry(
            term: "Gemini API Key",
            shortDefinition: "The private Google Gemini key Radix can use for automatic AI actions.",
            significance: "A Gemini API key lets Radix run supported AI workflows directly, such as captured-text checking, phrase extraction, translation, quiz prompt preparation, sentence extraction, and page-inspired practice. Copy-and-paste AI workflows still work without a key.",
            contexts: ["Settings > Automatic AI", "Browse page actions", "AI Link"],
            relatedTerms: ["API Key", "Run Automatically with Gemini", "AI Link", "Extract Sentences", "Sentence Practice", "Create Conversation"]
        ),
        GlossaryEntry(
            term: "Page AI Task",
            shortDefinition: "An AI action that uses a saved page as its source.",
            significance: "Page AI tasks include checking OCR, extracting phrases, translating a page, preparing a quiz prompt, extracting Sentences, and creating Conversation practice. Study and Browse use the same AI task flow; Study keeps page-owned learning work with the saved page.",
            contexts: ["Study page actions", "Browse page actions", "AI Link"],
            relatedTerms: ["Saved Page", "Copy to AI Chat", "Run Automatically with Gemini", "Extract Phrases", "Translation", "Quiz", "Extract Sentences", "Sentence Practice", "Create Conversation"]
        ),
        GlossaryEntry(
            term: "Extract Phrases",
            shortDefinition: "Ask AI to identify useful expressions inside real page text.",
            significance: "Phrase extraction can surface meaningful, current, or specialized expressions that are easy to miss or absent from a traditional dictionary. Review candidates before keeping them in Radix.",
            contexts: ["AI Link menu", "Import From AI", "Review Added Phrases"],
            relatedTerms: ["Added Phrase", "Classify & Prune", "Make AI Text Page"]
        ),
        GlossaryEntry(
            term: "Extract Sentences",
            shortDefinition: "Ask AI to turn a saved page into cleaned study text and sentence cards.",
            significance: "Extract Sentences keeps close to the source page while repairing obvious captured-text errors and expanding shorthand into complete Chinese sentences. Each extracted sentence can include Chinese, pinyin, English, and useful phrase hints, and becomes part of your saved sentences.",
            contexts: ["Study saved page actions", "AI Link", "Extracted Sentences", "Sentence Card"],
            relatedTerms: ["Sentence", "Saved Sentences", "Saved Page", "Sentence Practice", "Create Conversation"]
        ),
        GlossaryEntry(
            term: "Sentence Practice",
            shortDefinition: "Ask AI to create practice-pack sentences from a saved page.",
            significance: "Sentence Practice imports page-derived sentences into Conversation Practice with Chinese, pinyin, and English. Use it when you want a drillable practice pack rather than a cleaned sentence-by-sentence page.",
            contexts: ["Study saved page actions", "AI Link", "Import Practice", "Conversation Practice"],
            relatedTerms: ["Sentence", "Saved Sentences", "Practice Pack", "Conversation Practice", "Extract Sentences"]
        ),
        GlossaryEntry(
            term: "Create Conversation",
            shortDefinition: "Ask AI to create Conversation Practice inspired by a saved page's theme.",
            significance: "Create Conversation is broader than sentence extraction. It uses the saved page as a theme source, then creates useful conversation sentences around that topic, the learner's context, and current or timely examples when appropriate.",
            contexts: ["Browse page actions", "AI Link", "Import Practice", "Conversation Practice"],
            relatedTerms: ["Saved Page", "Conversation Practice", "Practice Pack", "Sentence Practice", "Extract Sentences"]
        ),
        GlossaryEntry(
            term: "Quiz",
            shortDefinition: "An AI chat quiz prompt created from a saved page and the learner's broader Chinese context.",
            significance: "Radix does not run a local page quiz. The Quiz action opens the AI Link route so the user can choose Copy to AI Chat or Run Automatically with Gemini, then continue the quiz in an AI chat with one question at a time.",
            contexts: ["Study page actions", "AI Link", "Saved Pages"],
            relatedTerms: ["Page AI Task", "Copy to AI Chat", "Run Automatically with Gemini", "Saved Page"]
        ),
        GlossaryEntry(
            term: "Translation",
            shortDefinition: "An AI-generated reading of a saved page based on its complete context.",
            significance: "Contextual translation aims to preserve meaning, tone, shorthand, subtext, and newer usage rather than translating each character separately. Save it with the original page for later comparison.",
            contexts: ["Browse page actions", "View Translation", "Save Translation", "Translate and Save"],
            relatedTerms: ["Saved Page", "AI Link"]
        ),
        GlossaryEntry(
            term: "Classify & Prune",
            shortDefinition: "Review added phrases and mark them as Unreviewed, Accepted, Hidden, or Rejected.",
            significance: "Use the status tools for fast classification. Accept Unreviewed marks all waiting candidates as useful; Remove Rejected and Remove Unreviewed clean up unwanted batches.",
            contexts: ["Backup Contents", "Phrases You Added", "Review Added Phrases"],
            relatedTerms: ["Added Phrase", "Accepted", "Hidden", "Rejected"]
        ),
        GlossaryEntry(
            term: "Make AI Text Page",
            shortDefinition: "Create a text page from added phrases so AI can inspect them again.",
            significance: "This helps you ask AI to sieve or clean a large phrase list using the exact characters in your added phrases.",
            contexts: ["Backup Contents", "Phrases You Added"],
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
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: entry.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(RadixAccent.primary)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.term)
                                .font(ResponsiveFont.subheadline.weight(.semibold))
                            Text(entry.shortDefinition)
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
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
            Section {
                Label(entry.term, systemImage: entry.systemImage)
                    .font(ResponsiveFont.headline.weight(.semibold))
            }

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
                            NavigationLink {
                                GlossaryDetailView(entry: relatedEntry)
                            } label: {
                                Label(term, systemImage: relatedEntry.systemImage)
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
