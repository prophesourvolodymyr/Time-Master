# P03 — Browser Agent Task

When the AI needs a token, auth code, or any info from a website that requires clicking, logging in, or navigating: instead of asking the user to do it manually, AI suggests generating a browser agent prompt saved to `/junk/` that another agent can execute.

## When to Use
- OAuth token retrieval from web consoles
- Scraping authenticated dashboards
- Any web interaction requiring login or navigation
