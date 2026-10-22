import { execFileSync } from "node:child_process";

const environment = { ...process.env };
delete environment.RESEND_API_KEY;
delete environment.RESEND_PROFILE;

function query(args) {
  try {
    return JSON.parse(execFileSync("resend", [...args, "--profile", "tmax", "--json"], {
      encoding: "utf8",
      env: environment,
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 30_000,
    }));
  } catch (error) {
    if (error.code === "ENOENT") {
      throw new Error("The Resend CLI is not installed or is not on PATH.");
    }
    let message = "The Tmax Resend profile could not be checked.";
    try {
      const response = JSON.parse(error.stderr?.toString() || error.stdout?.toString() || "{}");
      message = response.error?.message || message;
    } catch {}
    throw new Error(message);
  }
}

try {
  const identity = query(["whoami"]);
  if (!identity.authenticated || identity.profile !== "tmax") {
    throw new Error("The dedicated tmax profile is not authenticated.");
  }
  const domains = query(["domains", "list", "--limit", "100"]);
  console.log("Authenticated CLI profile: tmax");
  for (const domain of domains.data) {
    console.log(`Sending domain: ${domain.name} (${domain.status})`);
  }
  if (!domains.data.length) console.log("No sending domains configured in this profile's team.");
  if (domains.has_more) console.log("More domains are available through the Resend CLI.");
  console.log("Read-only check complete. No email was sent and no resources were changed.");
} catch (error) {
  console.error(error.message);
  console.error("Create/select a separate Tmax team in the Resend dashboard, then run npm run resend:login with that team's API key.");
  console.error("The existing default profile is never used as a fallback. Preview and export remain available without Resend.");
  process.exitCode = 1;
}
