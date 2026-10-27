import { spawn } from "node:child_process";

export const sleep = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

/** Runs a command to completion and resolves with its output; rejects with stderr on failure. */
export function run(command, args, { cwd, input, env } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, env: env ? { ...process.env, ...env } : process.env });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`${command} ${args.join(" ")} exited with ${code}\n${stderr || stdout}`));
    });
    child.stdin.end(input);
  });
}
