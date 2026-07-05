# F06-B — AI Database Creation

AI Coach can create and populate ExercisePages, child pages, and folders directly. User uploads media, describes what they want, AI builds the database structure.

## What We Build

### AI Actions (new tool-use capability for the AI)
- **Create page:** AI creates ExercisePage with title, notes, tags, links
- **Add child pages:** AI nests sub-pages under a parent (e.g., "Handstand" → "Wall Handstand" → "Freestanding")
- **Add media:** AI attaches photos/videos from user upload to pages
- **Set cover image:** AI picks or suggests cover from uploaded media
- **Add links:** AI adds external links (YouTube guides, articles) to pages
- **Set tags:** AI applies workout type tags
- **Bulk create:** "Upload these 10 photos of calisthenics exercises and create a page for each" → AI creates 10 pages with photos, names them, tags them

### User Flow
1. User goes to AI Coach chat
2. User uploads photos/videos (existing fileImporter)
3. User types: "Create a calisthenics folder with handstand, planche, and front lever. For handstand, add wall handstand and freestanding as sub-pages. Use these photos."
4. AI:
   - Creates "Calisthenics" root page with tag "calisthenics"
   - Creates "Handstand" child with 2 sub-children
   - Creates "Planche" and "Front Lever" children
   - Attaches uploaded photos to respective pages
5. AI responds: "Created Calisthenics with 3 exercises. Handstand has wall and freestanding progressions. Photos attached. Open Database to see."
6. User sees new pages in DatabaseView

### Implementation
- AI sends structured JSON in a special format that DatabaseStore processes
- DatabaseStore exposes: `createPage()`, `addChild()`, `attachMedia()`, `setCover()`, `addLink()`, `setTags()`
- AI uses function/tool calling to invoke these methods
- Confirmation message summarizes what was created with page count

## Architecture
```
ViewModels/
├── AIStore.swift                — add database tool-calling capability
└── DatabaseStore.swift          — add AI-facing creation methods

Views/AICoach/
└── AICoachView.swift            — render database creation results in chat
```

## Files
- `TimeMaster/ViewModels/AIStore.swift` (modify — add tool-calling)
- `TimeMaster/ViewModels/DatabaseStore.swift` (modify — add AI creation API)
- `TimeMaster/Views/AICoach/AICoachView.swift` (modify — render DB creation messages)

## Verification
- [ ] AI creates root page with title, tags, notes
- [ ] AI creates nested child pages (2+ levels deep)
- [ ] AI attaches user-uploaded media to specific pages
- [ ] AI sets cover images from uploaded media
- [ ] AI adds external links to pages
- [ ] Bulk creation: 5+ pages from multiple uploads
- [ ] Created pages appear in DatabaseView immediately
- [ ] AI response confirms what was created with page count
- [ ] compiles without errors
